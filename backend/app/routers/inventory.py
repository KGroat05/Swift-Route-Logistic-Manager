"""
Warehouse Inventory Management Router for Swift Route Logistics Manager.
Provides stock tracking, reorder alert queries, and cursor-based restock audit.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from ..database import get_db
from ..models import Inventory, User
from ..schemas import InventoryCreate, InventoryUpdate, InventoryResponse
from ..auth import get_current_user, require_role

router = APIRouter(prefix="/api/v1/inventory", tags=["Warehouse & Inventory Management"])

@router.get("", response_model=List[InventoryResponse])
def get_inventory(
    category: Optional[str] = Query(None, description="Filter by category"),
    low_stock_only: bool = Query(False, description="Filter items at or below reorder level"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve all inventory items with category and low-stock filters."""
    query = db.query(Inventory)
    if category:
        query = query.filter(Inventory.category == category)
    if low_stock_only:
        query = query.filter(Inventory.quantity <= Inventory.reorder_level)
    return query.order_by(Inventory.item_name.asc()).all()

@router.get("/low-stock")
def get_low_stock_view(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Directly queries the MySQL relational view `vw_low_stock_inventory`.
    Demonstrates View usage in the DBMS curriculum.
    """
    result = db.execute(text("SELECT * FROM vw_low_stock_inventory;"))
    keys = result.keys()
    items = [dict(zip(keys, row)) for row in result.fetchall()]
    return {
        "view_name": "vw_low_stock_inventory",
        "total_depleted_items": len(items),
        "items": items
    }

@router.post("/audit-restock")
def execute_restock_audit(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """
    Executes MySQL Stored Procedure `sp_audit_inventory_restock`.
    Uses CURSOR to iterate over items below reorder level and computes procurement requirements.
    """
    conn = db.connection().connection
    cursor = conn.cursor()
    try:
        cursor.callproc("sp_audit_inventory_restock", (0, 0.0))
        # Fetch the latest generated report from analytics
        cursor.execute("SELECT id, report_type, generated_at, data FROM analytics_reports WHERE report_type = 'INVENTORY_RESTOCK_AUDIT' ORDER BY generated_at DESC LIMIT 1;")
        row = cursor.fetchone()
        return {
            "procedure_name": "sp_audit_inventory_restock",
            "audit_id": row[0],
            "generated_at": row[2].isoformat() if row[2] else None,
            "audit_summary": row[3]
        }
    finally:
        cursor.close()

@router.post("", response_model=InventoryResponse, status_code=status.HTTP_201_CREATED)
def create_inventory_item(
    payload: InventoryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Add a new inventory SKU."""
    if db.query(Inventory).filter(Inventory.item_code == payload.item_code).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Item code SKU already exists.")

    item = Inventory(
        item_code=payload.item_code,
        item_name=payload.item_name,
        description=payload.description,
        category=payload.category,
        quantity=payload.quantity,
        unit_of_measure=payload.unit_of_measure,
        reorder_level=payload.reorder_level,
        unit_cost=payload.unit_cost,
        location=payload.location
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item

@router.put("/{item_id}", response_model=InventoryResponse)
def update_inventory_item(
    item_id: str,
    payload: InventoryUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """
    Update inventory quantities and attributes.
    Protected by database trigger `trg_inventory_check_zero` preventing negative values.
    """
    item = db.query(Inventory).filter(Inventory.id == item_id).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inventory item not found.")

    update_data = payload.dict(exclude_unset=True)
    for field, val in update_data.items():
        setattr(item, field, val)

    try:
        db.commit()
        db.refresh(item)
        return item
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Database constraint violation: {str(e)}")
