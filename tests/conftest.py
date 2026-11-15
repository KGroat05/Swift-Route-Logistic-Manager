"""
Pytest Fixtures for Swift Route Logistics Manager.
Configures FastAPI TestClient and pre-authenticates roles.
"""
import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent.parent / "backend"
sys.path.insert(0, str(backend_dir))

from app.main import app

@pytest.fixture(scope="session")
def client():
    """Provides FastAPI TestClient instance."""
    with TestClient(app) as c:
        yield c

@pytest.fixture(scope="session")
def admin_token(client):
    """Retrieves JWT token for Admin."""
    res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "admin123"})
    assert res.status_code == 200, f"Admin login failed: {res.text}"
    return res.json()["access_token"]

@pytest.fixture(scope="session")
def dispatcher_token(client):
    """Retrieves JWT token for Dispatcher."""
    res = client.post("/api/v1/auth/login", json={"username": "dispatcher", "password": "dispatcher123"})
    assert res.status_code == 200, f"Dispatcher login failed: {res.text}"
    return res.json()["access_token"]

@pytest.fixture(scope="session")
def viewer_token(client):
    """Retrieves JWT token for Viewer."""
    res = client.post("/api/v1/auth/login", json={"username": "viewer", "password": "viewer123"})
    assert res.status_code == 200, f"Viewer login failed: {res.text}"
    return res.json()["access_token"]

@pytest.fixture
def admin_headers(admin_token):
    return {"Authorization": f"Bearer {admin_token}"}

@pytest.fixture
def dispatcher_headers(dispatcher_token):
    return {"Authorization": f"Bearer {dispatcher_token}"}

@pytest.fixture
def viewer_headers(viewer_token):
    return {"Authorization": f"Bearer {viewer_token}"}
