# Full-Stack Architecture Specification
## Swift Route Logistics Manager
**Course:** 21CSC205P Database Management Systems  
**Institution:** SRM Institute of Science and Technology  
**Student:** Krishang Gupta (RA2411026010810)  
**Supervisor:** Dr. Amit Kukker  

---

## 1. Architectural Layers

The system is structured as a decoupled 3-tier enterprise architecture:

```
+--------------------------------------------------------------+
|                     PRESENTATION LAYER                       |
|  - HTML5, CSS3, JavaScript (ES6+), Bootstrap 5.3, Chart.js  |
|  - SPA Navigation, Dynamic DOM rendering, Toast alerts       |
|  - Interactive SQL Lab & Real-Time Concurrency Simulator     |
+------------------------------+-------------------------------+
                               | RESTful JSON (HTTP / CORS)
                               v
+--------------------------------------------------------------+
|                     APPLICATION LAYER                        |
|  - Python 3.13 + FastAPI Framework                          |
|  - JWT Bearer Authentication & RBAC (Admin, Dispatcher)      |
|  - Pydantic v2 Schema Validation                             |
|  - SQLAlchemy 2.0 ORM & Connection Pooling                   |
|  - Stored Procedure & Trigger Execution Delegates            |
+------------------------------+-------------------------------+
                               | TCP Socket / PyMySQL Protocol
                               v
+--------------------------------------------------------------+
|                      DATABASE LAYER                          |
|  - MySQL 8.4 LTS Server                                      |
|  - InnoDB Storage Engine (Row-level Locking, MVCC, 2PL)      |
|  - 12 Normalized Relational Tables (1NF - 5NF)               |
|  - Triggers, Stored Procedures with Cursors, Views, Indexes  |
+--------------------------------------------------------------+
```

---

## 2. Authentication & Role-Based Access Control (RBAC)

The security subsystem enforces Role-Based Access Control via JSON Web Tokens (JWT) signed using HMAC-SHA256:

| Role | Permissions & Privileges |
|---|---|
| **`ADMIN`** | Full superuser privileges. User account creation, schema management, customer deletion, fleet decommissioning, execution of all stored procedures, destructive SQL Lab access. |
| **`DISPATCHER`** | Operational logistics privileges. Create and edit shipments, assign vehicles and drivers, trigger status transitions, mark invoices paid, update warehouse quantities, execute restock audits. |
| **`VIEWER`** | Read-only auditor privileges. View dashboard KPIs, search shipments, inspect live tracking timelines, query relational views, execute read-only queries (`SELECT`, `SHOW`) in SQL Lab. |

---

## 3. Database Access Layer & Transaction Management

- **SQLAlchemy 2.0 Engine**:
  Maintains connection pooling with `pool_pre_ping=True`, mitigating stale connections.
- **PyMySQL Driver**:
  Native Python MySQL client connecting via port 3306 with `utf8mb4` charset.
- **Transaction Isolation & Concurrency**:
  - Uses MySQL InnoDB's default **REPEATABLE READ** isolation level.
  - Mitigates dirty reads and non-repeatable reads using Multi-Version Concurrency Control (MVCC) undo logs.
  - Implements **Pessimistic Row Locking** (`SELECT ... FOR UPDATE`) during vehicle dispatch to prevent simultaneous double-booking.
  - Uses explicit **Savepoints** (`SAVEPOINT sp_name`) and selective rollback (`ROLLBACK TO SAVEPOINT sp_name`) to ensure transactional atomicity.
