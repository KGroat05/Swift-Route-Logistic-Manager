"""
Customer CRUD & Validation Tests.
"""
import uuid

def test_list_customers(client, viewer_headers):
    res = client.get("/api/v1/customers", headers=viewer_headers)
    assert res.status_code == 200
    assert len(res.json()) >= 8

def test_create_and_delete_customer(client, admin_headers):
    rand_email = f"test.customer.{uuid.uuid4().hex[:6]}@example.com"
    payload = {
        "name": "Acme Aerospace Corp",
        "contact_name": "Rohan Gupta",
        "contact_email": rand_email,
        "contact_phone": "+91-9876543210",
        "address": "Electronic City Tech Zone",
        "city": "Bengaluru",
        "state": "Karnataka",
        "postal_code": "560100"
    }
    # Create
    res = client.post("/api/v1/customers", json=payload, headers=admin_headers)
    assert res.status_code == 201
    cust_id = res.json()["id"]

    # Read
    res_get = client.get(f"/api/v1/customers/{cust_id}", headers=admin_headers)
    assert res_get.status_code == 200
    assert res_get.json()["name"] == "Acme Aerospace Corp"

    # Delete
    res_del = client.delete(f"/api/v1/customers/{cust_id}", headers=admin_headers)
    assert res_del.status_code == 204
