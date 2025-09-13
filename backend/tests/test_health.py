from fastapi.testclient import TestClient
from app.main import app


client = TestClient(app)


def test_health_route():
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data.get("service") == "backend"
    assert data.get("status") == "ok"

