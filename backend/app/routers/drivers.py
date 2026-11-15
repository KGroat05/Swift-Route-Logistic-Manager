"""
Driver Management Router for Swift Route Logistics Manager.
Provides CRUD operations, status filters, and cursor-based payout calculation.
"""
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import text
from ..database import get_db
from ..models import Driver, User
from ..schemas import DriverCreate, DriverUpdate, DriverResponse
from ..auth import get_current_user, require_role

router = APIRouter(prefix="/api/v1/drivers", tags=["Driver Management"])

@router.get("", response_model=List[DriverResponse])
def get_drivers(
    status: Optional[str] = Query(None, description="Filter by driver status (ACTIVE, ON_DUTY, ON_LEAVE, SUSPENDED)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve all drivers with optional status filtering."""
    query = db.query(Driver)
    if status:
        query = query.filter(Driver.status == status)
    return query.order_by(Driver.name.asc()).all()

@router.get("/available", response_model=List[DriverResponse])
def get_available_drivers(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve all drivers currently ACTIVE and ready for dispatch."""
    return db.query(Driver).filter(Driver.status == "ACTIVE").order_by(Driver.name.asc()).all()

@router.get("/payouts/calculate")
def calculate_driver_payouts(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """
    Executes MySQL Stored Procedure `sp_calculate_driver_payout`.
    Demonstrates CURSOR iteration over drivers and completed deliveries.
    """
    connection = db.connection().connection
    cursor = connection.cursor()
    try:
        cursor.callproc("sp_calculate_driver_payout", (0, 0.0))
        rows = cursor.fetchall()
        payouts = []
        for r in rows:
            payouts.append({
                "driver_id": r[0],
                "driver_name": r[1],
                "completed_deliveries": r[2],
                "total_distance_km": float(r[3]),
                "base_salary": float(r[4]),
                "trip_bonus": float(r[5]),
                "distance_incentive": float(r[6]),
                "net_payout_inr": float(r[7])
            })
        return {
            "procedure_name": "sp_calculate_driver_payout",
            "cursor_type": "InnoDB Cursor with CONTINUE HANDLER",
            "total_drivers_processed": len(payouts),
            "payout_breakdown": payouts
        }
    finally:
        cursor.close()

@router.get("/{driver_id}", response_model=DriverResponse)
def get_driver(
    driver_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve single driver details by UUID."""
    driver = db.query(Driver).filter(Driver.id == driver_id).first()
    if not driver:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Driver not found.")
    return driver

@router.post("", response_model=DriverResponse, status_code=status.HTTP_201_CREATED)
def create_driver(
    payload: DriverCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Register a new commercial driver."""
    if db.query(Driver).filter(Driver.license_number == payload.license_number).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Driver license number already exists.")
    if db.query(Driver).filter(Driver.email == payload.email).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Driver email already registered.")

    driver = Driver(
        name=payload.name,
        license_number=payload.license_number,
        phone=payload.phone,
        email=payload.email,
        status=payload.status,
        hired_date=payload.hired_date,
        experience_years=payload.experience_years or 1
    )
    db.add(driver)
    db.commit()
    db.refresh(driver)
    return driver

@router.put("/{driver_id}", response_model=DriverResponse)
def update_driver(
    driver_id: str,
    payload: DriverUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Update driver profile or status."""
    driver = db.query(Driver).filter(Driver.id == driver_id).first()
    if not driver:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Driver not found.")

    update_data = payload.dict(exclude_unset=True)
    for field, val in update_data.items():
        setattr(driver, field, val)

    db.commit()
    db.refresh(driver)
    return driver

@router.delete("/{driver_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_driver(
    driver_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN"]))
):
    """Delete driver record (Admin only)."""
    driver = db.query(Driver).filter(Driver.id == driver_id).first()
    if not driver:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Driver not found.")

    db.delete(driver)
    db.commit()
    return None
