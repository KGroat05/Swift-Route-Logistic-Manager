"""
Shipment Lifecycle, Booking, and Tracking Tests.
"""
def test_list_shipments(client, viewer_headers):
    res = client.get("/api/v1/shipments", headers=viewer_headers)
    assert res.status_code == 200
    assert len(res.json()) >= 9

def test_track_shipment_by_number(client):
    # Public tracking should work without auth
    res = client.get("/api/v1/shipments/track/SR-2026-1001")
    assert res.status_code == 200
    data = res.json()
    assert data["tracking_number"] == "SR-2026-1001"
    assert len(data["tracking_events"]) >= 3

def test_book_shipment_capacity_validation(client, dispatcher_headers):
    # Attempting to assign heavy cargo exceeding vehicle payload
    # veh-003 is available with 7000kg capacity. We attempt 12000kg:
    payload = {
        "customer_id": "cst-001",
        "origin_address": "Hosur Depot",
        "destination_address": "Bengaluru Hub",
        "weight": 12000.0,
        "volume": 25.0,
        "cargo_type": "Steel Heavy Coils",
        "route_id": "rt-001",
        "vehicle_id": "veh-003",  # Capacity is only 7000kg
        "billing_amount": 15000.0
    }
    res = client.post("/api/v1/shipments", json=payload, headers=dispatcher_headers)
    assert res.status_code == 422
    assert "exceeds vehicle payload capacity" in res.json()["detail"]

def test_book_and_transition_shipment(client, dispatcher_headers):
    # Book a valid shipment
    payload = {
        "customer_id": "cst-002",
        "origin_address": "Madhavaram Terminal",
        "destination_address": "Tambaram Mini Hub",
        "weight": 350.0,
        "volume": 2.5,
        "cargo_type": "E-Commerce Packages",
        "route_id": "rt-006",
        "billing_amount": 5400.0
    }
    res = client.post("/api/v1/shipments", json=payload, headers=dispatcher_headers)
    assert res.status_code == 201
    shp_id = res.json()["id"]

    # Transition status: PENDING -> BOOKED
    res_booked = client.post(
        f"/api/v1/shipments/{shp_id}/status",
        json={"status": "BOOKED", "location": "Madhavaram Terminal", "notes": "Carrier allocated."},
        headers=dispatcher_headers
    )
    assert res_booked.status_code == 200
    assert res_booked.json()["status"] == "BOOKED"

    # Transition status: BOOKED -> IN_TRANSIT
    status_payload = {
        "status": "IN_TRANSIT",
        "location": "Kathipara Junction Checkpoint",
        "notes": "Passed through south arterial corridor."
    }
    res_status = client.post(f"/api/v1/shipments/{shp_id}/status", json=status_payload, headers=dispatcher_headers)
    assert res_status.status_code == 200
    assert res_status.json()["status"] == "IN_TRANSIT"

    # Transition status to DELIVERED
    status_deliv = {
        "status": "DELIVERED",
        "location": "Tambaram Mini Hub",
        "notes": "Packages unloaded and verified against manifest."
    }
    res_deliv = client.post(f"/api/v1/shipments/{shp_id}/status", json=status_deliv, headers=dispatcher_headers)
    assert res_deliv.status_code == 200
    assert res_deliv.json()["status"] == "DELIVERED"
