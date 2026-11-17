import json
import pathlib

PROM = {"type": "prometheus", "uid": "prometheus"}
LOKI = {"type": "loki", "uid": "loki"}
OUT = pathlib.Path(__file__).resolve().parent.parent / "monitoring/grafana/dashboards"


def q(expr, legend=""):
    return {"refId": "", "expr": expr, "legendFormat": legend}


def ts(pid, title, x, y, w, h, targets, unit=None):
    for i, t in enumerate(targets):
        t["refId"] = chr(65 + i)
    defaults = {"unit": unit} if unit else {}
    return {
        "id": pid, "type": "timeseries", "title": title, "datasource": PROM,
        "gridPos": {"x": x, "y": y, "w": w, "h": h}, "targets": targets,
        "fieldConfig": {"defaults": defaults, "overrides": []},
    }


def logs(pid, title, x, y, w, h, expr):
    return {
        "id": pid, "type": "logs", "title": title, "datasource": LOKI,
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "targets": [{"refId": "A", "expr": expr, "queryType": "range"}],
        "options": {"showTime": True, "wrapLogMessage": True, "sortOrder": "Descending"},
    }


def write(uid, title, panels):
    dash = {
        "uid": uid, "title": title, "schemaVersion": 39, "version": 1,
        "refresh": "10s", "time": {"from": "now-30m", "to": "now"},
        "tags": [], "templating": {"list": []}, "panels": panels,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"{uid}.json").write_text(json.dumps(dash, indent=2) + "\n")
    print("wrote", uid)
