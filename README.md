# Swift Route Logistics Manager
### 21CSC205P Database Management Systems — Mini Project Report & Implementation
**Department of Networking and Communications | School of Computing**  
**SRM Institute of Science and Technology, Ghaziabad — 201 204**  

* **Submitted by:** Krishang Gupta (`RA2411026010810`)
* **Degree:** Bachelor of Technology in Computer Science Engineering (AIML)
* **Under the Guidance of:** Dr. Amit Kukker (Assistant Professor, Dept. of Computational Intelligence)
* **Academic Term:** September – October 2026

---

## Executive Summary

**Swift Route Logistics Manager** is an enterprise-grade, relational DBMS mini-project built to model and optimize modern supply chain and courier operations in urban India. The system centralizes customer accounts, shipment booking, vehicle and driver fleet management, route planning, real-time milestone tracking, invoicing, and warehouse inventory control.

The project demonstrates advanced database engineering principles including:
* **Relational Normalization up to 5NF** with documented functional, multivalued, and join dependencies.
* **ACID Transactions & Concurrency Control** utilizing InnoDB Two-Phase Locking (2PL), pessimistic row locking (`SELECT ... FOR UPDATE`), savepoints, and rollback mechanisms.
* **Database Programmability**: Stored procedures utilizing **Cursors**, deterministic stored functions, and reactive automated **Triggers**.
* **Analytical Views & Multi-Table Joins**: 5 specialized views demonstrating aggregate queries, window functions (`ROW_NUMBER`, `DENSE_RANK`), subqueries (`EXISTS`, `NOT IN`), and set operations (`UNION`).
* **Role-Based Access Control (RBAC)**: Secure Bcrypt password hashing and JWT authorization supporting `ADMIN`, `DISPATCHER`, and `VIEWER` roles.
* **Interactive SQL Lab**: Built-in developer and evaluator workbench to run raw SQL queries, inspect execution timings in milliseconds, and test live concurrency scenarios.

---

## Technology Stack

| Layer | Technologies Used |
|---|---|
| **Frontend** | HTML5, CSS3, Modern JavaScript (ES6+ SPA), Bootstrap 5.3, Bootstrap Icons, Chart.js |
| **Backend API** | Python 3.13, FastAPI, Pydantic v2 validation, Starlette |
| **Database Engine** | **MySQL 8.4 LTS** (Community Server with InnoDB Engine) |
| **Database Access** | SQLAlchemy 2.0 ORM & Native PyMySQL Driver with connection pooling |
| **Security & Auth** | Bcrypt (12-round salt hashing), PyJWT (HS256 tokens), OAuth2 Bearer flow |
| **Testing & Docs** | Pytest (19 integration tests), FastAPI Swagger UI (`/docs`), ReDoc (`/redoc`) |

---

## Directory Structure

```
D:\DBMS\
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py              # FastAPI application, CORS, static mount, router registration
│   │   ├── config.py            # Environment settings and database connection string
│   │   ├── database.py          # SQLAlchemy engine, session maker, get_db dependency
│   │   ├── models.py            # 12 SQLAlchemy ORM mapped entities
│   │   ├── schemas.py           # Pydantic v2 request/response models
│   │   ├── auth.py              # Bcrypt password hashing, JWT generation, RBAC middleware
│   │   ├── routers/
│   │   │   ├── auth.py          # Login, token issuance, user management
│   │   │   ├── customers.py     # Customer CRUD operations and searches
│   │   │   ├── shipments.py     # Booking, lifecycle transitions, capacity checks, cancellation
│   │   │   ├── drivers.py       # Driver roster & sp_calculate_driver_payout (Cursor)
│   │   │   ├── vehicles.py      # Fleet roster, availability, payload capacity
│   │   │   ├── routes.py        # Route catalog and distance measurements
│   │   │   ├── assignments.py   # Shift scheduling & conflict prevention
│   │   │   ├── tracking.py      # Milestone timeline audit events
│   │   │   ├── billing.py       # Invoices, GST computations, payment processing
│   │   │   ├── inventory.py     # Warehouse stock, low-stock view, sp_audit_inventory_restock
│   │   │   ├── analytics.py     # Dashboard KPIs and relational view endpoints
│   │   │   └── sql_demo.py      # SQL Lab query runner & Concurrency / Savepoint simulator
│   │   └── utils/
│   ├── .env.example             # Example environment configuration
│   ├── .env                     # Local environment credentials
│   └── requirements.txt         # Python package dependencies
├── frontend/
│   ├── index.html               # Logistics Manager Single Page Application
│   ├── css/
│   │   └── styles.css           # Custom responsive styles, timeline UI, status badges
│   └── js/
│       ├── api.js               # Fetch client with auto-Bearer JWT injection
│       ├── auth.js              # Session manager and quick role switcher
│       └── app.js               # UI view switcher, charts, modal controllers, SQL Lab
├── database/
│   ├── 01_schema.sql            # DDL: 12 normalized tables with foreign keys and check constraints
│   ├── 02_sample_data.sql       # Seed data for Indian logistics operations (Chennai, Bengaluru, etc.)
│   ├── 03_views.sql             # 5 Relational views (driver performance, routes, financials, low stock)
│   ├── 04_procedures.sql        # Stored procedures with cursors, transactions, and freight function
│   ├── 05_triggers.sql          # 5 Reactive triggers (auto tracking logs, weight validation, payment sync)
│   ├── 06_indexes.sql           # Performance B-Tree indexes for foreign keys, statuses, and search columns
│   ├── 07_advanced_queries.sql  # 8 Academic syllabus queries (HAVING, 5-way joins, subqueries, UNION)
│   ├── 08_concurrency_transactions_demo.sql # 2PL locking, SAVEPOINT, ROLLBACK, and isolation scripts
│   └── init_db.py               # Automated Python database setup & migration runner
├── tests/
│   ├── conftest.py              # Pytest client and role-authenticated headers fixtures
│   ├── test_auth.py             # Authentication and RBAC tests
│   ├── test_customers.py        # Customer CRUD and unique constraint tests
│   ├── test_shipments.py        # Shipment booking, capacity validation, lifecycle tests
│   ├── test_billing_and_inventory.py # Invoices, payment triggers, restock audit tests
│   └── test_sql_lab.py          # SQL query runner, views, and concurrency simulation tests
├── docs/
│   ├── ER_DIAGRAM.md            # Detailed Mermaid ER diagram and cardinality analysis
│   ├── RELATIONAL_SCHEMA.md     # Complete column definitions, types, default values, and foreign keys
│   ├── NORMALIZATION_ANALYSIS.md# Rigorous normalization proof (1NF, 2NF, 3NF, BCNF, 4NF, 5NF)
│   └── ARCHITECTURE.md          # 3-tier architecture, RBAC model, and concurrency specifications
├── scripts/
│   ├── setup_mysql.py           # Portable MySQL 8.4 LTS automatic downloader and initializer
│   ├── run_all.bat              # One-click Windows batch starter
│   └── run_all.ps1              # One-click Windows PowerShell starter
└── README.md
```

---

## Relational Database Architecture (12 Tables)

1. **`users`**: System authentication, Bcrypt passwords, and roles (`ADMIN`, `DISPATCHER`, `VIEWER`).
2. **`customers`**: Corporate clients, contact emails, phone numbers, and physical addresses.
3. **`routes`**: Predefined logistics corridors, origin/destination terminals, distance in km, toll fees.
4. **`vehicles`**: Fleet management, license plates, models, payload capacities (kg & m³), statuses (`AVAILABLE`, `IN_USE`, `MAINTENANCE`, `RETIRED`).
5. **`drivers`**: Commercial drivers, heavy vehicle licenses, experience years, statuses (`ACTIVE`, `ON_DUTY`, `ON_LEAVE`, `SUSPENDED`).
6. **`driver_assignments`**: M:N scheduling junction assigning driver + vehicle + route over dated shift intervals.
7. **`shipments`**: Core consignment table tracking cargo, origin, destination, weights, assigned resources, and operational statuses (`PENDING`, `BOOKED`, `IN_TRANSIT`, `OUT_FOR_DELIVERY`, `DELIVERED`, `CANCELLED`).
8. **`tracking_events`**: Immutable timeline event log recording chronological checkpoints, locations, and status remarks.
9. **`billing`**: Tax invoices linked to shipments, amounts, 18% GST tax, stored generated `total_amount`, and payment statuses (`UNPAID`, `PAID`, `OVERDUE`).
10. **`inventory`**: Warehouse packaging supplies, unit costs, stock quantities, and reorder alert thresholds (`CHECK (quantity >= 0)`).
11. **`partner_integrations`**: External 3PL dispatch APIs and tracking hooks.
12. **`analytics`**: JSON report snapshots and aggregation cache.

---

## Advanced DBMS Concepts Demonstrated

### 1. Database Triggers (`05_triggers.sql`)
* `trg_after_shipment_insert`: Automatically creates the initial tracking audit event whenever a shipment is inserted.
* `trg_after_shipment_update`: Automatically detects status changes (`OLD.status <> NEW.status`) and inserts a chronological checkpoint with origin/destination coordinates.
* `trg_enforce_shipment_weight_check`: Enforces `weight > 0` before insertion, throwing custom SQLSTATE `45000` on violation.
* `trg_invoice_payment_sync`: Automatically populates the `paid_at` timestamp when an invoice status changes to `PAID`.
* `trg_inventory_check_zero`: Prevents stock levels from ever going below zero.

### 2. Stored Procedures & Functions (`04_procedures.sql`)
* `fn_calculate_freight_charge`: Deterministic function calculating logistics freight cost: $\text{Base Rate (₹500)} + (2.50 \times \text{Weight}) + (6.00 \times \text{Distance})$.
* `sp_book_shipment_with_assignment`: Full transaction verifying customer existence, driver readiness, and vehicle payload capacity. Acquires row lock, sets savepoint, inserts shipment, and dispatches resources.
* `sp_update_shipment_status`: Transitions shipment status, adds tracking event, and automatically releases assigned driver and vehicle upon delivery or cancellation.
* `sp_calculate_driver_payout`: **Demonstrates CURSOR iteration**. Opens cursor over drivers, calculates trip bonuses and mileage incentives, and outputs temporary table payout results.
* `sp_audit_inventory_restock`: **Demonstrates CURSOR iteration**. Scans depleted warehouse inventory where $\text{quantity} \le \text{reorder\_level}$, computes restocking requirements, and saves a JSON report in `analytics`.

### 3. Concurrency Control & ACID Guarantees (`08_concurrency_transactions_demo.sql`)
* **Two-Phase Locking (2PL)**: Explicit pessimistic row locking using `SELECT ... FOR UPDATE` prevents two concurrent dispatchers from double-booking the same delivery vehicle.
* **Savepoints & Rollback**: Demonstrates `SAVEPOINT sp_name` and `ROLLBACK TO SAVEPOINT sp_name` for partial error recovery without aborting the entire transaction.
* **Repeatable Read Isolation**: Prevents dirty reads and non-repeatable reads using InnoDB Multi-Version Concurrency Control (MVCC).

### 4. Relational Views (`03_views.sql`)
* `vw_shipment_details`: 5-table join displaying customer, shipment, vehicle, driver, route, and invoice details.
* `vw_driver_performance`: Computes delivery success rates, total delivered distance, and average payload per driver using `GROUP BY` and `CASE`.
* `vw_route_analytics`: Computes cargo volume and revenue generated per kilometer for every predefined route.
* `vw_financial_summary`: Summarizes receivables, collected funds, GST tax, and collection efficiency percentage.
* `vw_low_stock_inventory`: Filters warehouse SKUs below reorder thresholds and calculates deficit restocking costs.

---

## Quickstart & Windows Run Instructions

### Prerequisites
* Windows 10 or Windows 11 (64-bit)
* Python 3.10+ (Tested on Python 3.13.2)
* Port 3306 and Port 8000 available

### Option A: One-Click Launch (Recommended)
Simply double-click:
```cmd
D:\DBMS\scripts\run_all.bat
```
or run from PowerShell:
```powershell
& "D:\DBMS\scripts\run_all.ps1"
```
This automatically starts MySQL 8.4 LTS, runs the database migrations, and launches the FastAPI backend.

---

### Option B: Manual Step-by-Step Launch

#### 1. Setup Python Dependencies
```cmd
cd /d "D:\DBMS"
pip install -r backend\requirements.txt
```

#### 2. Start MySQL 8.4 Server
```cmd
"D:\DBMS\mysql_server\mysql-8.4.4-winx64\bin\mysqld.exe" --defaults-file="D:\DBMS\mysql_server\my.ini" --console
```

#### 3. Initialize Database Schema & Seed Data
In a second terminal:
```cmd
cd /d "D:\DBMS"
python database\init_db.py
```

#### 4. Launch FastAPI Web Application
```cmd
cd /d "D:\DBMS"
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --app-dir "D:\DBMS\backend" --reload
```

#### 5. Open Web Portal & Swagger UI
* **Logistics Management Dashboard**: Open [http://127.0.0.1:8000](http://127.0.0.1:8000)
* **FastAPI Interactive Swagger UI**: Open [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
* **ReDoc API Documentation**: Open [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)

---

## Default User Accounts & RBAC Credentials

| Role | Username | Password | Privileges |
|---|---|---|---|
| **System Admin** | `admin` | `admin123` | Full access, user creation, customer deletion, SQL Lab DDL |
| **Chief Dispatcher** | `dispatcher` | `dispatcher123` | Book shipments, update statuses, assign fleet, mark invoices paid |
| **Auditor / Viewer** | `viewer` | `viewer123` | Read-only access to dispatches, tracking, views, read-only SQL Lab |

*Tip: The web dashboard includes a quick **Role Switcher** in the top navigation bar to seamlessly evaluate different role privileges.*

---

## Running Automated Tests

Run the full automated integration test suite covering authentication, RBAC, CRUD, constraints, capacity validation, views, and concurrency control:

```cmd
cd /d "D:\DBMS"
python -m pytest tests -v
```

**Test Results Summary**:
```
tests/test_auth.py::test_health_check PASSED                             [  5%]
tests/test_auth.py::test_login_success PASSED                            [ 10%]
tests/test_auth.py::test_login_invalid_password PASSED                   [ 15%]
tests/test_auth.py::test_rbac_admin_endpoint_forbidden_for_viewer PASSED [ 21%]
tests/test_auth.py::test_rbac_admin_endpoint_allowed_for_admin PASSED    [ 26%]
tests/test_billing_and_inventory.py::test_list_invoices PASSED           [ 31%]
tests/test_billing_and_inventory.py::test_update_invoice_payment PASSED  [ 36%]
tests/test_billing_and_inventory.py::test_inventory_low_stock_view PASSED [ 42%]
tests/test_billing_and_inventory.py::test_inventory_audit_restock_procedure PASSED [ 47%]
tests/test_customers.py::test_list_customers PASSED                      [ 52%]
tests/test_customers.py::test_create_and_delete_customer PASSED          [ 57%]
tests/test_shipments.py::test_list_shipments PASSED                      [ 63%]
tests/test_shipments.py::test_track_shipment_by_number PASSED            [ 68%]
tests/test_shipments.py::test_book_shipment_capacity_validation PASSED   [ 73%]
tests/test_shipments.py::test_book_and_transition_shipment PASSED        [ 78%]
tests/test_sql_lab.py::test_preloaded_queries PASSED                     [ 84%]
tests/test_sql_lab.py::test_execute_sql_query PASSED                     [ 89%]
tests/test_sql_lab.py::test_concurrency_and_transaction_demo PASSED      [ 94%]
tests/test_sql_lab.py::test_driver_payout_cursor_procedure PASSED        [100%]

======================= 19 passed in 8.55s =======================
```

---

## Academic Project Alignment (21CSC205P Syllabus)

| Syllabus Chapter | Requirement Title | System Implementation |
|---|---|---|
| **Chapter 1** | Problem understanding, Entity & Relationships, ER Model | [docs/ER_DIAGRAM.md](docs/ER_DIAGRAM.md), 12 Relational Entities |
| **Chapter 2** | Relational Schemas, Creation of Database & Tables | [database/01_schema.sql](database/01_schema.sql), [docs/RELATIONAL_SCHEMA.md](docs/RELATIONAL_SCHEMA.md) |
| **Chapter 3.1** | Aggregate functions, Constraints, Sets | [database/07_advanced_queries.sql](database/07_advanced_queries.sql) (Queries 1, 5) |
| **Chapter 3.2** | Subqueries, Joins, and Views | [database/03_views.sql](database/03_views.sql), [database/07_advanced_queries.sql](database/07_advanced_queries.sql) (Queries 2, 3, 4) |
| **Chapter 3.3** | Functions, Triggers, Cursors & Exception Handling | [database/04_procedures.sql](database/04_procedures.sql), [database/05_triggers.sql](database/05_triggers.sql) |
| **Chapter 4.1** | Normalization Analysis: 1NF, 2NF, 3NF | [docs/NORMALIZATION_ANALYSIS.md](docs/NORMALIZATION_ANALYSIS.md) (§1, §2, §3) |
| **Chapter 4.2** | Normalization Analysis: 4NF, 5NF | [docs/NORMALIZATION_ANALYSIS.md](docs/NORMALIZATION_ANALYSIS.md) (§4) |
| **Chapter 5** | Concurrency Control and Recovery Mechanisms | [database/08_concurrency_transactions_demo.sql](database/08_concurrency_transactions_demo.sql), Two-Phase Locking, Savepoint Rollback |
| **Chapter 6** | Front-end and Back-End Implementation Code | [backend/app/](backend/app/), [frontend/](frontend/) (Bootstrap 5 + FastAPI) |
| **Chapter 7** | Results and Discussions | Interactive SQL Lab, Real-time Dashboard, 19 Automated Tests |
