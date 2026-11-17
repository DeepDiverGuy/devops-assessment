import json
import logging
import os
import sys
import time

import uvicorn
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
PORT = int(os.getenv("PORT", "8080"))
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
ENVIRONMENT = os.getenv("ENVIRONMENT", "local")

REQUESTS = Counter("http_requests_total", "Total HTTP requests", ["method", "path", "status"])
ERRORS = Counter("http_errors_total", "Total HTTP 5xx responses", ["method", "path"])
LATENCY = Histogram("http_request_duration_seconds", "Request latency in seconds", ["method", "path"])

EXTRA_FIELDS = ("method", "path", "status", "duration_ms")


class JsonFormatter(logging.Formatter):
    def format(self, record):
        entry = {
            "time": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "message": record.getMessage(),
            "env": ENVIRONMENT,
            "version": APP_VERSION,
        }
        for key in EXTRA_FIELDS:
            if hasattr(record, key):
                entry[key] = getattr(record, key)
        return json.dumps(entry)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logging.basicConfig(level=LOG_LEVEL, handlers=[handler], force=True)
log = logging.getLogger("app")

app = FastAPI(title="devops-task")


@app.middleware("http")
async def observe(request: Request, call_next):
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        elapsed = time.perf_counter() - start
        route = request.scope.get("route")
        path = route.path if route else "unmatched"
        REQUESTS.labels(request.method, path, str(status)).inc()
        LATENCY.labels(request.method, path).observe(elapsed)
        if status >= 500:
            ERRORS.labels(request.method, path).inc()
            level = logging.ERROR
        elif path in ("/health", "/metrics"):
            level = logging.DEBUG
        else:
            level = logging.INFO
        log.log(
            level,
            "request",
            extra={
                "method": request.method,
                "path": path,
                "status": status,
                "duration_ms": round(elapsed * 1000, 2),
            },
        )


@app.get("/")
def root():
    return {"message": "Hello from DevOps Task!", "status": "running", "version": APP_VERSION}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/error")
def error():
    # Deliberate 500, used later to demo error spikes and alerts.
    return JSONResponse({"detail": "simulated failure"}, status_code=500)


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


if __name__ == "__main__":
    log.info("starting")
    # uvicorn handles SIGTERM: it stops accepting new requests and finishes in-flight ones.
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_config=None, access_log=False)
