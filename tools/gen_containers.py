from dash import q, ts, write

panels = [
    ts(1, "CPU per container (cores)", 0, 0, 12, 8,
       [q('sum by (name) (rate(container_cpu_usage_seconds_total{name!=""}[5m]))', "{{name}}")]),
    ts(2, "Memory per container", 12, 0, 12, 8,
       [q('container_memory_working_set_bytes{name!=""}', "{{name}}")], "bytes"),
    ts(3, "Memory usage vs limit (%)", 0, 8, 24, 8,
       [q('100 * container_memory_working_set_bytes{name!=""} / (container_spec_memory_limit_bytes{name!=""} > 0)',
          "{{name}}")], "percent"),
]
write("containers", "Containers", panels)
