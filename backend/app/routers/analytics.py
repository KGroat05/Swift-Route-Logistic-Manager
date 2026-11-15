"""
Analytics & Operational Reports Router for Swift Route Logistics Manager.
Provides dashboard metrics, aggregations, and direct queries to MySQL relational views.
"""
from typing import Dict, Any, List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from ..database import get_db
from ..models import Shipment, Customer, Driver, Vehicle, Billing, Inventory, User
from ..schemas import DashboardKPIs
from ..auth import get_current_user

router = APIRouter(prefix="/api/v1/analytics", tags=["Analytical Reports & Dashboards"])

@router.get("/dashboard", response_model=DashboardKPIs)
def get_dashboard_kpis(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Real-time operational logistics dashboard KPIs."""
    total_cust = db.query(Customer).count()
    total_shp = db.query(Shipment).count()
    active_shp = db.query(Shipment).filter(Shipment.status.in_(["BOOKED", "IN_TRANSIT", "OUT_FOR_DELIVERY"])).count()
    deliv_shp = db.query(Shipment).filter(Shipment.status == "DELIVERED").count()
    act_drv = db.query(Driver).filter(Driver.status.in_(["ACTIVE", "ON_DUTY"])).count()
    avail_veh = db.query(Vehicle).filter(Vehicle.status == "AVAILABLE").count()
    low_stock = db.query(Inventory).filter(Inventory.quantity <= Inventory.reorder_level).count()

    # Financial queries
    fin_res = db.execute(text("SELECT collected_revenue, (pending_receivables + overdue_receivables) FROM vw_financial_summary;")).fetchone()
    collected_rev = fin_res[0] if fin_res and fin_res[0] is not None else 0.00

    overdue_count = db.query(Billing).filter(Billing.status.in_(["UNPAID", "OVERDUE"])).count()

    return {
        "total_customers": total_cust,
        "total_shipments": total_shp,
        "active_shipments": active_shp,
        "delivered_shipments": deliv_shp,
        "active_drivers": act_drv,
        "available_vehicles": avail_veh,
        "total_revenue_inr": collected_rev,
        "pending_invoices_count": overdue_count,
        "low_stock_items_count": low_stock
    }

@router.get("/views/driver-performance")
def get_driver_performance_view(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Direct query of relational view: `vw_driver_performance`."""
    res = db.execute(text("SELECT * FROM vw_driver_performance ORDER BY delivered_shipments DESC;"))
    keys = res.keys()
    return [dict(zip(keys, row)) for row in res.fetchall()]

@router.get("/views/route-analytics")
def get_route_analytics_view(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Direct query of relational view: `vw_route_analytics`."""
    res = db.execute(text("SELECT * FROM vw_route_analytics ORDER BY total_revenue_generated DESC;"))
    keys = res.keys()
    return [dict(zip(keys, row)) for row in res.fetchall()]

@router.get("/views/financial-summary")
def get_financial_summary_view(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Direct query of relational view: `vw_financial_summary`."""
    res = db.execute(text("SELECT * FROM vw_financial_summary;"))
    keys = res.keys()
    row = res.fetchone()
    return dict(zip(keys, row)) if row else {}

@router.get("/shipment-status-distribution")
def get_shipment_status_distribution(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Aggregated shipment status distribution for chart visualization."""
    res = db.execute(text("SELECT status, COUNT(*) AS count FROM shipments GROUP BY status;"))
    return [{"status": row[0], "count": row[1]} for row in res.fetchall()]
