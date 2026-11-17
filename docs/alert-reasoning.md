## Alert rules: thresholds and `for` durations

| Alert | Condition | for | Severity | Why |
|---|---|---|---|---|
| AppInstanceDown | `up{job="app"} == 0` | 1m | critical | Scrape interval is short, so 1m rides out a restart or a single failed scrape but still pages quickly for a real outage. |
| HighErrorRate | error ratio over 5m > 5% | 5m | warning | A ratio (not a raw count) works at any traffic level. 5% is far above normal noise. The 5m rate window plus 5m `for` filters short blips. `clamp_min` avoids divide-by-zero when idle. |
| HostDiskUsageHigh | any real filesystem > 80% | 10m | warning | 80% leaves time to react before full. Disk fills slowly, so 10m avoids flapping around the threshold. tmpfs/overlay/squashfs/efivarfs are excluded as they are virtual or always full. |
| ContainerMemoryNearLimit | working set > 90% of limit | 5m | warning | Working set is what the OOM killer acts on. 90% gives headroom to investigate before an OOM kill. `limit > 0` skips containers with no limit set. |
| HighP95Latency | p95 > 500ms | 5m | warning | p95 reflects what slow users see without being distorted by single outliers. Sustained 5m means a real degradation, not one slow request. |

Principles: page (critical) only on user-visible outage; everything else is a warning.
`for` durations trade detection speed against false positives.
