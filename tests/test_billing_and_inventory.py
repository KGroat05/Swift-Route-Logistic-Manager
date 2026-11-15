"""
Billing and Inventory Tests.
"""
def test_list_invoices(client, viewer_headers):
    res = client.get("/api/v1/billing", headers=viewer_headers)
    assert res.status_code == 200
    assert len(res.json()) >= 7

def test_update_invoice_payment(client, dispatcher_headers):
    # Find an unpaid invoice
    res_list = client.get("/api/v1/billing?status=UNPAID", headers=dispatcher_headers)
    assert res_list.status_code == 200
    invoices = res_list.json()
    if invoices:
        inv_id = invoices[0]["id"]
        res_pay = client.put(
            f"/api/v1/billing/{inv_id}/payment",
            json={"status": "PAID", "payment_method": "UPI"},
            headers=dispatcher_headers
        )
        assert res_pay.status_code == 200
        assert res_pay.json()["status"] == "PAID"
        assert res_pay.json()["payment_method"] == "UPI"

def test_inventory_low_stock_view(client, viewer_headers):
    res = client.get("/api/v1/inventory/low-stock", headers=viewer_headers)
    assert res.status_code == 200
    data = res.json()
    assert "items" in data
    assert data["view_name"] == "vw_low_stock_inventory"

def test_inventory_audit_restock_procedure(client, admin_headers):
    res = client.post("/api/v1/inventory/audit-restock", headers=admin_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["procedure_name"] == "sp_audit_inventory_restock"
    assert "audit_summary" in data
