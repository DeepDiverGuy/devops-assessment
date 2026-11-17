from dash import q, ts, write

FS = 'fstype!~"tmpfs|overlay|squashfs|devtmpfs|efivarfs"'
NET = 'device!~"lo|veth.*|docker.*|br-.*"'

panels = [
    ts(1, "CPU usage (%)", 0, 0, 12, 8,
       [q('100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)', "cpu %")], "percent"),
    ts(2, "Memory usage (%)", 12, 0, 12, 8,
       [q("100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)", "memory %")], "percent"),
    ts(3, "Disk usage by mount (%)", 0, 8, 12, 8,
       [q(f"100 * (1 - node_filesystem_avail_bytes{{{FS}}} / node_filesystem_size_bytes{{{FS}}})",
          "{{mountpoint}}")], "percent"),
    ts(4, "Network throughput (bytes/s)", 12, 8, 12, 8, [
        q(f"sum by (device) (rate(node_network_receive_bytes_total{{{NET}}}[5m]))", "rx {{device}}"),
        q(f"sum by (device) (rate(node_network_transmit_bytes_total{{{NET}}}[5m]))", "tx {{device}}"),
    ], "Bps"),
]
write("host", "Host", panels)
