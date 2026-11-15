"""
Swift Route Logistics Manager - FastAPI Main Application.
College DBMS Mini-Project for 21CSC205P Database Management Systems.
Author: Krishang Gupta (RA2411026010810) | Guide: Dr. Amit Kukker
SRM Institute of Science and Technology
"""
import os
from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from .config import settings
from .routers import (
    auth, customers, shipments, drivers, vehicles,
    routes, assignments, tracking, billing, inventory,
    analytics, sql_demo
)

app = FastAPI(
    title="Swift Route Logistics Manager API",
    description="""
## Swift Route Logistics Manager
A comprehensive, relational DBMS-driven logistics and supply chain management system.

### DBMS Concepts Demonstrated:
* **Relational Schema**: 12 normalized tables up to 5NF with primary/foreign keys and check constraints.
* **ACID Transactions**: Savepoints, atomic booking pipelines, and rollback mechanisms.
* **Concurrency Control**: Pessimistic row locking (`SELECT ... FOR UPDATE`) and InnoDB MVCC.
* **Advanced SQL**: Multi-table JOINs, correlated subqueries, set operations, window functions, and views.
* **Programmability**: Stored procedures with cursors, deterministic functions, and automatic reactive triggers.
* **Security**: Role-Based Access Control (Admin, Dispatcher, Viewer) with Bcrypt and JWT.
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Enable CORS — restricted to local development origins only.
# Frontend is served from the same FastAPI process, so same-origin requests
# never require CORS. These origins cover external dev tools and localhost variants.
_cors_origins = [
    "http://127.0.0.1:8000",
    "http://localhost:8000",
    "http://127.0.0.1:5500",   # VS Code Live Server
    "http://localhost:5500",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

# Include Routers
app.include_router(auth.router)
app.include_router(customers.router)
app.include_router(shipments.router)
app.include_router(drivers.router)
app.include_router(vehicles.router)
app.include_router(routes.router)
app.include_router(assignments.router)
app.include_router(tracking.router)
app.include_router(billing.router)
app.include_router(inventory.router)
app.include_router(analytics.router)
app.include_router(sql_demo.router)

# Frontend Static Files Mount
FRONTEND_DIR = Path(__file__).resolve().parent.parent.parent / "frontend"

if FRONTEND_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(FRONTEND_DIR)), name="static")

    @app.get("/", include_in_schema=False)
    def serve_frontend_index():
        """Serve the Logistics Portal Single Page App."""
        index_file = FRONTEND_DIR / "index.html"
        if index_file.exists():
            return FileResponse(index_file)
        return {"message": "Swift Route Logistics Manager API is running. Swagger UI available at /docs"}

@app.get("/health", tags=["Health"])
def health_check():
    """System health check and database connectivity confirmation."""
    return {
        "status": "healthy",
        "system": "Swift Route Logistics Manager",
        "engine": "MySQL 8.4 LTS",
        "version": "1.0.0"
    }
