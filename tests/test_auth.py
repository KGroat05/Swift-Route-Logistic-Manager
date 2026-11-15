"""
Authentication & Authorization Tests for Swift Route Logistics Manager.
"""
def test_health_check(client):
    res = client.get("/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "healthy"
    assert data["engine"] == "MySQL 8.4 LTS"

def test_login_success(client):
    res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "admin123"})
    assert res.status_code == 200
    data = res.json()
    assert "access_token" in data
    assert data["user"]["role"] == "ADMIN"

def test_login_invalid_password(client):
    res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "wrongpassword"})
    assert res.status_code == 401

def test_rbac_admin_endpoint_forbidden_for_viewer(client, viewer_headers):
    # Viewer should be forbidden from accessing admin users list
    res = client.get("/api/v1/auth/users", headers=viewer_headers)
    assert res.status_code == 403

def test_rbac_admin_endpoint_allowed_for_admin(client, admin_headers):
    res = client.get("/api/v1/auth/users", headers=admin_headers)
    assert res.status_code == 200
    assert len(res.json()) >= 3
