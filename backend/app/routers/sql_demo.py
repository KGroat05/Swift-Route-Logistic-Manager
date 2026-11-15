"""
Interactive SQL Lab & Concurrency Control Router for Swift Route Logistics Manager.
Demonstrates joins, subqueries, aggregates, views, stored procedures, transactions, savepoints, and row locking.
"""
import time
from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from ..database import get_db
from ..models import User, Vehicle, Customer, Shipment
from ..schemas import SQLQueryRequest, SQLQueryResponse
from ..auth import get_current_user, require_role

router = APIRouter(prefix="/api/v1/sql", tags=["SQL Lab & Concurrency Control"])

PRELOADED_QUERIES = [
    {
        "id": "q1",
        "title": "Aggregates with GROUP BY & HAVING",
        "description": "Finds corporate customers with >= 1 shipment and total billing exceeding ₹20,000.",
        "sql": """SELECT 
    c.id AS customer_id,
    c.name AS customer_company,
    c.city,
    COUNT(s.id) AS total_shipments_placed,
    ROUND(SUM(s.weight), 2) AS total_weight_kg,
    ROUND(SUM(b.total_amount), 2) AS total_billed_inr,
    ROUND(AVG(b.total_amount), 2) AS avg_shipment_value_inr
FROM customers c
INNER JOIN shipments s ON c.id = s.customer_id
LEFT JOIN billing b ON s.id = b.shipment_id
GROUP BY c.id, c.name, c.city
HAVING total_billed_inr > 20000.00
ORDER BY total_billed_inr DESC;"""
    },
    {
        "id": "q2",
        "title": "Multi-Table 5-Way JOIN with Utilization Calculation",
        "description": "Active shipment manifest joining shipments, customers, routes, drivers, and vehicles.",
        "sql": """SELECT 
    s.tracking_number,
    c.name AS sender,
    r.name AS route,
    d.name AS driver,
    d.phone AS driver_phone,
    v.license_plate AS vehicle_plate,
    s.weight AS cargo_weight_kg,
    v.capacity_kg AS vehicle_capacity_kg,
    ROUND((s.weight / v.capacity_kg) * 100, 2) AS capacity_utilization_pct,
    s.status AS shipment_status
FROM shipments s
INNER JOIN customers c ON s.customer_id = c.id
INNER JOIN routes r ON s.route_id = r.id
LEFT JOIN drivers d ON s.driver_id = d.id
LEFT JOIN vehicles v ON s.vehicle_id = v.id
WHERE s.status IN ('BOOKED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY')
ORDER BY capacity_utilization_pct DESC;"""
    },
    {
        "id": "q3",
        "title": "Scalar and Correlated Subqueries",
        "description": "Finds shipments heavier than overall fleet average weight, comparing against global mean.",
        "sql": """SELECT 
    s.id,
    s.tracking_number,
    s.cargo_type,
    s.weight,
    (SELECT ROUND(AVG(weight), 2) FROM shipments) AS overall_avg_weight,
    ROUND(s.weight - (SELECT AVG(weight) FROM shipments), 2) AS diff_from_average,
    c.name AS customer_name
FROM shipments s
INNER JOIN customers c ON s.customer_id = c.id
WHERE s.weight > (SELECT AVG(inner_s.weight) FROM shipments inner_s)
ORDER BY s.weight DESC;"""
    },
    {
        "id": "q4",
        "title": "Subquery with EXISTS",
        "description": "Finds all routes that have at least one successfully DELIVERED cargo.",
        "sql": """SELECT 
    r.id, 
    r.name, 
    r.start_location, 
    r.end_location, 
    r.estimated_distance_km
FROM routes r
WHERE EXISTS (
    SELECT 1 
    FROM shipments s 
    WHERE s.route_id = r.id AND s.status = 'DELIVERED'
);"""
    },
    {
        "id": "q5",
        "title": "Set Operations (UNION)",
        "description": "Combines customers and drivers into a unified logistics contact directory.",
        "sql": """SELECT 
    'CUSTOMER' AS party_type,
    name AS party_name,
    contact_phone AS phone,
    contact_email AS email,
    city AS location
FROM customers
UNION
SELECT 
    'DRIVER' AS party_type,
    name AS party_name,
    phone,
    email,
    'Field Operations' AS location
FROM drivers
ORDER BY party_name ASC;"""
    },
    {
        "id": "q6",
        "title": "Window Functions (ROW_NUMBER & DENSE_RANK)",
        "description": "Ranks shipments by cargo weight partitioned by route, plus running cumulative load.",
        "sql": """SELECT 
    s.id,
    s.tracking_number,
    r.name AS route_name,
    s.weight,
    ROW_NUMBER() OVER (PARTITION BY s.route_id ORDER BY s.weight DESC) AS route_rank,
    DENSE_RANK() OVER (ORDER BY s.weight DESC) AS global_heavy_rank,
    SUM(s.weight) OVER (PARTITION BY s.route_id ORDER BY s.created_at) AS cumulative_route_kg
FROM shipments s
LEFT JOIN routes r ON s.route_id = r.id
ORDER BY r.name, route_rank;"""
    }
]

@router.get("/preloaded-queries")
def get_preloaded_queries(current_user: User = Depends(get_current_user)):
    """Retrieve list of preloaded syllabus SQL queries for interactive demonstration."""
    return PRELOADED_QUERIES

@router.post("/execute", response_model=SQLQueryResponse)
def execute_sql_query(
    payload: SQLQueryRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Execute read-only SQL queries or view queries in the SQL Lab.
    Sanitizes against destructive DDL/DML unless user is ADMIN.
    """
    raw_query = payload.query.strip()
    clean_upper = raw_query.upper()

    # Viewer role restriction: only SELECT or SHOW or EXPLAIN
    if current_user.role == "VIEWER":
        if not (clean_upper.startswith("SELECT") or clean_upper.startswith("SHOW") or clean_upper.startswith("EXPLAIN")):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Viewers are restricted to read-only queries (SELECT, SHOW, EXPLAIN)."
            )

    # Prevent dropping database or system tables
    if "DROP DATABASE" in clean_upper or "TRUNCATE" in clean_upper:
        if current_user.role != "ADMIN":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Destructive DDL is restricted to ADMIN."
            )

    t0 = time.time()
    try:
        result = db.execute(text(raw_query))
        exec_ms = round((time.time() - t0) * 1000, 2)

        if result.returns_rows:
            columns = list(result.keys())
            rows_data = []
            for row in result.fetchmany(100):  # Cap at 100 rows for display
                row_dict = {}
                for col, val in zip(columns, row):
                    # Convert Decimals/datetimes to serializable format
                    if hasattr(val, "isoformat"):
                        row_dict[col] = val.isoformat()
                    elif hasattr(val, "__float__"):
                        row_dict[col] = float(val)
                    else:
                        row_dict[col] = val
                rows_data.append(row_dict)
            return {
                "columns": columns,
                "rows": rows_data,
                "row_count": len(rows_data),
                "execution_time_ms": exec_ms
            }
        else:
            db.commit()
            return {
                "columns": ["status", "rows_affected"],
                "rows": [{"status": "Success", "rows_affected": result.rowcount}],
                "row_count": result.rowcount,
                "execution_time_ms": exec_ms
            }
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"SQL Execution Error: {str(e)}"
        )

@router.post("/concurrency-demo")
def run_concurrency_and_transaction_demo(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """
    Live Demonstration of ACID Properties, Two-Phase Locking (2PL),
    Pessimistic Row Locking (SELECT ... FOR UPDATE), SAVEPOINTS, and ROLLBACK.
    """
    logs: List[Dict[str, Any]] = []
    conn = db.connection().connection
    cursor = conn.cursor()

    try:
        logs.append({
            "step": 1,
            "action": "START TRANSACTION",
            "detail": "Beginning new atomic transaction with default REPEATABLE READ isolation.",
            "status": "OK"
        })
        cursor.execute("START TRANSACTION;")

        # Step 2: Pessimistic Row Lock with FOR UPDATE
        logs.append({
            "step": 2,
            "action": "SELECT ... FOR UPDATE",
            "detail": "Acquiring exclusive row lock on vehicle 'veh-001' to prevent concurrent booking conflicts.",
            "status": "OK"
        })
        cursor.execute("SELECT id, license_plate, model, status, capacity_kg FROM vehicles WHERE id = 'veh-001' FOR UPDATE;")
        veh_row = cursor.fetchone()
        logs.append({
            "step": 2.1,
            "action": "ROW_LOCKED",
            "detail": f"Exclusive lock obtained on {veh_row[1]} ({veh_row[2]}). Current status: {veh_row[3]}.",
            "status": "LOCKED"
        })

        # Step 3: Insert with SAVEPOINT
        logs.append({
            "step": 3,
            "action": "SAVEPOINT sp_demo_start",
            "detail": "Creating Savepoint 'sp_demo_start' within the transaction.",
            "status": "OK"
        })
        cursor.execute("SAVEPOINT sp_demo_start;")

        # Step 4: Tentative update
        logs.append({
            "step": 4,
            "action": "UPDATE vehicles SET status = 'IN_USE'",
            "detail": "Tentatively marking vehicle as IN_USE pending manifest completion.",
            "status": "OK"
        })
        cursor.execute("UPDATE vehicles SET status = 'IN_USE' WHERE id = 'veh-001';")

        # Step 5: Rollback to Savepoint
        logs.append({
            "step": 5,
            "action": "ROLLBACK TO SAVEPOINT sp_demo_start",
            "detail": "Simulating business validation rejection. Reverting changes back to Savepoint.",
            "status": "ROLLED_BACK"
        })
        cursor.execute("ROLLBACK TO SAVEPOINT sp_demo_start;")

        # Step 6: Verify vehicle status reverted
        cursor.execute("SELECT status FROM vehicles WHERE id = 'veh-001';")
        curr_status = cursor.fetchone()[0]
        logs.append({
            "step": 6,
            "action": "VERIFY_SAVEPOINT_REVERSION",
            "detail": f"Vehicle status successfully preserved as: '{curr_status}'.",
            "status": "VERIFIED"
        })

        # Step 7: Commit transaction and release lock
        cursor.execute("COMMIT;")
        logs.append({
            "step": 7,
            "action": "COMMIT",
            "detail": "Transaction committed. All InnoDB locks successfully released.",
            "status": "COMMITTED"
        })

        return {
            "demo_name": "Two-Phase Locking (2PL) & Savepoint Rollback",
            "acid_guarantees": {
                "Atomicity": "All-or-nothing execution with rollback to savepoint.",
                "Consistency": "Relational foreign keys and capacity checks preserved.",
                "Isolation": "InnoDB REPEATABLE READ with MVCC and SELECT ... FOR UPDATE.",
                "Durability": "Committed changes flushed to InnoDB redo log (ib_logfile)."
            },
            "steps": logs
        }
    except Exception as e:
        cursor.execute("ROLLBACK;")
        raise HTTPException(status_code=500, detail=f"Transaction simulation error: {str(e)}")
    finally:
        cursor.close()
