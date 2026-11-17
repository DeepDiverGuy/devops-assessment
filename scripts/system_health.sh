#!/usr/bin/env bash
# system_health.sh - collect host health metrics, log them, and flag thresholds.
set -euo pipefail

CPU_T=90
MEM_T=85
DISK_T=80
CRIT=95
JSON=0
LOG_FILE="${HEALTH_LOG:-health_log.txt}"
MAX_BYTES=1048576
KEEP=5
STATUS=0
MSGS=()

usage() {
  cat <<'USAGE'
Usage: system_health.sh [options]

Collects CPU, memory, disk (all filesystems), load average and top 5
processes by memory. Appends a timestamped entry to the log file.

Options:
  --cpu N          CPU warning threshold, percent (default 90)
  --mem N          Memory warning threshold, percent (default 85)
  --disk N         Disk warning threshold per filesystem, percent (default 80)
  --critical N     Critical threshold for any metric, percent (default 95)
  --json           Output and log entries as JSON (one object per line)
  --log-file PATH  Log file (default ./health_log.txt, or $HEALTH_LOG)
  --max-size BYTES Rotate the log when it reaches this size (default 1048576)
  --keep N         Number of rotated logs to keep (default 5)
  -h, --help       Show this help

Exit codes: 0 = healthy, 1 = warning, 2 = critical, 3 = usage error.
USAGE
}

need_val() {
  if [[ $# -lt 2 ]]; then
    echo "Error: $1 requires a value" >&2
    exit 3
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu) need_val "$@"; CPU_T=$2; shift 2 ;;
    --mem) need_val "$@"; MEM_T=$2; shift 2 ;;
    --disk) need_val "$@"; DISK_T=$2; shift 2 ;;
    --critical) need_val "$@"; CRIT=$2; shift 2 ;;
    --max-size) need_val "$@"; MAX_BYTES=$2; shift 2 ;;
    --keep) need_val "$@"; KEEP=$2; shift 2 ;;
    --log-file) need_val "$@"; LOG_FILE=$2; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown option $1" >&2; usage >&2; exit 3 ;;
  esac
done

for v in CPU_T MEM_T DISK_T CRIT MAX_BYTES KEEP; do
  if [[ ! "${!v}" =~ ^[0-9]+$ ]]; then
    echo "Error: $v must be a non-negative integer (got '${!v}')" >&2
    exit 3
  fi
done

cpu_sample() {
  local user nice system idle iowait irq softirq steal
  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  echo "$((idle + iowait)) $((user + nice + system + idle + iowait + irq + softirq + steal))"
}

cpu_usage() {
  local i1 t1 i2 t2 dt di
  read -r i1 t1 <<<"$(cpu_sample)"
  sleep 1
  read -r i2 t2 <<<"$(cpu_sample)"
  dt=$((t2 - t1))
  di=$((i2 - i1))
  if (( dt > 0 )); then
    echo $(( (100 * (dt - di)) / dt ))
  else
    echo 0
  fi
}

mem_usage() {
  awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2}
       END { if (t > 0) printf "%d", (t - a) * 100 / t; else print 0 }' /proc/meminfo
}

disk_usage() {
  df -P -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs | awk 'NR > 1 { gsub("%", "", $5); print $6, $5 }'
}

top_procs() {
  ps -eo pid=,%mem=,comm= --sort=-%mem | sed -n '1,5p'
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

alert() {
  local level=$1 msg=$2
  MSGS+=("$msg")
  if (( level > STATUS )); then
    STATUS=$level
  fi
  if (( JSON )); then
    echo "$msg" >&2
  else
    echo "$msg"
  fi
}

check() {
  local name=$1 value=$2 thr=$3
  if (( value >= CRIT )); then
    alert 2 "[CRITICAL] ${name} usage ${value}% (critical at ${CRIT}%)"
  elif (( value > thr )); then
    alert 1 "[WARNING] ${name} usage ${value}% exceeds ${thr}%"
  fi
}

rotate_log() {
  [[ -f "$LOG_FILE" ]] || return 0
  local size i
  size=$(stat -c %s "$LOG_FILE")
  if (( size >= MAX_BYTES )); then
    for (( i = KEEP - 1; i >= 1; i-- )); do
      if [[ -f "$LOG_FILE.$i" ]]; then
        mv -f "$LOG_FILE.$i" "$LOG_FILE.$((i + 1))"
      fi
    done
    mv -f "$LOG_FILE" "$LOG_FILE.1"
  fi
}

cpu=$(cpu_usage)
mem=$(mem_usage)
read -r l1 l5 l15 _ < /proc/loadavg
cores=$(nproc)
mapfile -t disks < <(disk_usage)
mapfile -t procs < <(top_procs)

check "CPU" "$cpu" "$CPU_T"
check "Memory" "$mem" "$MEM_T"
for d in "${disks[@]}"; do
  check "Disk ${d% *}" "${d##* }" "$DISK_T"
done
if awk -v l="$l1" -v c="$cores" 'BEGIN { exit !(l > c) }'; then
  alert 1 "[WARNING] Load average ${l1} exceeds CPU cores (${cores})"
fi

case "$STATUS" in
  0) label="OK" ;;
  1) label="WARNING" ;;
  *) label="CRITICAL" ;;
esac

ts=$(date -Iseconds)
host=$(hostname)

if (( JSON )); then
  disks_json=""
  for d in "${disks[@]}"; do
    disks_json+="${disks_json:+,}{\"mount\":\"$(json_escape "${d% *}")\",\"used_percent\":${d##* }}"
  done
  procs_json=""
  for p in "${procs[@]}"; do
    read -r pid pmem comm <<<"$p"
    procs_json+="${procs_json:+,}{\"pid\":${pid},\"mem_percent\":${pmem},\"command\":\"$(json_escape "$comm")\"}"
  done
  warn_json=""
  for m in "${MSGS[@]}"; do
    warn_json+="${warn_json:+,}\"$(json_escape "$m")\""
  done
  entry="{\"timestamp\":\"${ts}\",\"host\":\"$(json_escape "$host")\",\"status\":\"${label}\",\"cpu_percent\":${cpu},\"memory_percent\":${mem},\"load\":{\"1m\":${l1},\"5m\":${l5},\"15m\":${l15},\"cores\":${cores}},\"disks\":[${disks_json}],\"top_processes\":[${procs_json}],\"warnings\":[${warn_json}]}"
else
  disks_txt=""
  for d in "${disks[@]}"; do
    disks_txt+="${disks_txt:+ }${d% *}=${d##* }%"
  done
  procs_txt=""
  for p in "${procs[@]}"; do
    read -r pid pmem comm <<<"$p"
    procs_txt+="${procs_txt:+,}${pid}:${comm// /_}:${pmem}%"
  done
  entry="${ts} host=${host} status=${label} cpu=${cpu}% mem=${mem}% load=${l1},${l5},${l15} disks=\"${disks_txt}\" top_mem=\"${procs_txt}\""
fi

mkdir -p "$(dirname "$LOG_FILE")"
rotate_log
printf '%s\n' "$entry" | tee -a "$LOG_FILE"

exit "$STATUS"
