from dash import logs, q, ts, write

panels = [
    ts(1, "Request rate (req/s)", 0, 0, 12, 8,
       [q("sum by (path) (rate(http_requests_total[5m]))", "{{path}}")], "reqps"),
    ts(2, "Error rate (%)", 12, 0, 12, 8,
       [q("(100 * sum(rate(http_errors_total[5m])) / sum(rate(http_requests_total[5m]))) or vector(0)", "5xx %")],
       "percent"),
    ts(3, "Latency p50 / p95 / p99", 0, 8, 24, 8, [
        q("histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))", "p50"),
        q("histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))", "p95"),
        q("histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))", "p99"),
    ], "s"),
    logs(4, "App error logs (Loki)", 0, 16, 24, 10, '{container="devops-task", level="ERROR"}'),
]
write("application", "Application", panels)
