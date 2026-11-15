"""
SQL Lab and Concurrency Demo Tests.
"""
def test_preloaded_queries(client, viewer_headers):
    res = client.get("/api/v1/sql/preloaded-queries", headers=viewer_headers)
    assert res.status_code == 200
    assert len(res.json()) >= 6

def test_execute_sql_query(client, viewer_headers):
    query = "SELECT status, COUNT(*) AS cnt FROM shipments GROUP BY status;"
    res = client.post("/api/v1/sql/execute", json={"query": query}, headers=viewer_headers)
    assert res.status_code == 200
    data = res.json()
    assert "columns" in data
    assert "rows" in data
    assert "status" in data["columns"]
    assert "cnt" in data["columns"]
    assert data["row_count"] > 0

def test_concurrency_and_transaction_demo(client, admin_headers):
    res = client.post("/api/v1/sql/concurrency-demo", headers=admin_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["demo_name"] == "Two-Phase Locking (2PL) & Savepoint Rollback"
    assert "acid_guarantees" in data
    assert len(data["steps"]) >= 7
    # Verify savepoint rollback was logged
    actions = [s["action"] for s in data["steps"]]
    assert "START TRANSACTION" in actions
    assert "SELECT ... FOR UPDATE" in actions
    assert "SAVEPOINT sp_demo_start" in actions
    assert "ROLLBACK TO SAVEPOINT sp_demo_start" in actions
    assert "COMMIT" in actions

def test_driver_payout_cursor_procedure(client, admin_headers):
    res = client.get("/api/v1/drivers/payouts/calculate", headers=admin_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["procedure_name"] == "sp_calculate_driver_payout"
    assert len(data["payout_breakdown"]) >= 7
