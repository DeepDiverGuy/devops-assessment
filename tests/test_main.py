from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root():
    r = client.get("/")
    assert r.status_code == 200
    body = r.json()
    assert body["message"] == "Hello from DevOps Task!"
    assert body["status"] == "running"
    assert "version" in body


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_error_endpoint_returns_500():
    assert client.get("/error").status_code == 500


def test_metrics_exposes_required_metrics():
    client.get("/")
    client.get("/error")
    text = client.get("/metrics").text
    assert "http_requests_total" in text
    assert "http_errors_total" in text
    assert "http_request_duration_seconds_bucket" in text
