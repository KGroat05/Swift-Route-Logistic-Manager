"""
Shipment Core Router for Swift Route Logistics Manager.
Handles booking, lifecycle status transitions, cancellation, tracking, and capacity validation.
"""
from decimal import Decimal
from typing import List, Optional
import uuid
from datetime import datetime, date
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import Shipment, Customer, Route, Driver, Vehicle, Billing, TrackingEvent, User
from ..schemas import (
    ShipmentCreate, ShipmentUpdate, ShipmentStatusUpdate,
    ShipmentResponse, ShipmentDetailResponse
)
from ..auth import get_current_user, require_role

router = APIRouter(prefix="/api/v1/shipments", tags=["Shipment Lifecycle & Bookings"])

def generate_tracking_number(db: Session) -> str:
    """Generate sequential or unique tracking code."""
    year = datetime.utcnow().year
    count = db.query(Shipment).count() + 1
    return f"SR-{year}-{1000 + count}"

@router.get("", response_model=List[ShipmentResponse])
def get_shipments(
    status: Optional[str] = Query(None, description="Filter by status (PENDING, BOOKED, IN_TRANSIT, OUT_FOR_DELIVERY, DELIVERED, CANCELLED)"),
    customer_id: Optional[str] = Query(None, description="Filter by customer UUID"),
    route_id: Optional[str] = Query(None, description="Filter by route UUID"),
    driver_id: Optional[str] = Query(None, description="Filter by driver UUID"),
    vehicle_id: Optional[str] = Query(None, description="Filter by vehicle UUID"),
    search: Optional[str] = Query(None, description="Search tracking number or addresses"),
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve all shipments with rich multi-attribute filters."""
    query = db.query(Shipment)
    if status:
        query = query.filter(Shipment.status == status)
    if customer_id:
        query = query.filter(Shipment.customer_id == customer_id)
    if route_id:
        query = query.filter(Shipment.route_id == route_id)
    if driver_id:
        query = query.filter(Shipment.driver_id == driver_id)
    if vehicle_id:
        query = query.filter(Shipment.vehicle_id == vehicle_id)
    if search:
        s = f"%{search}%"
        query = query.filter(
            (Shipment.tracking_number.ilike(s)) |
            (Shipment.origin_address.ilike(s)) |
            (Shipment.destination_address.ilike(s)) |
            (Shipment.cargo_type.ilike(s))
        )
    return query.order_by(Shipment.created_at.desc()).offset(skip).limit(limit).all()

@router.get("/track/{tracking_number}", response_model=ShipmentDetailResponse)
def track_shipment_by_number(
    tracking_number: str,
    db: Session = Depends(get_db)
):
    """Public lookup: track shipment milestone timeline by tracking number."""
    shipment = db.query(Shipment).filter(Shipment.tracking_number == tracking_number).first()
    if not shipment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Tracking number '{tracking_number}' not found.")
    return shipment

@router.get("/{shipment_id}", response_model=ShipmentDetailResponse)
def get_shipment(
    shipment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve complete shipment detail with timeline events and billing."""
    shipment = db.query(Shipment).filter(Shipment.id == shipment_id).first()
    if not shipment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shipment not found.")
    return shipment

@router.post("", response_model=ShipmentResponse, status_code=status.HTTP_201_CREATED)
def book_shipment(
    payload: ShipmentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """
    Book a new shipment with database transaction.
    Validates vehicle capacity against cargo weight, customer existence, and driver availability.
    """
    # 1. Validate Customer
    customer = db.query(Customer).filter(Customer.id == payload.customer_id).first()
    if not customer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Selected customer does not exist.")

    # 2. Validate Vehicle Capacity & Status (if vehicle assigned)
    vehicle = None
    if payload.vehicle_id:
        vehicle = db.query(Vehicle).filter(Vehicle.id == payload.vehicle_id).with_for_update().first()
        if not vehicle:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Selected vehicle not found.")
        if vehicle.status != "AVAILABLE":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Vehicle {vehicle.license_plate} is not available (Current status: {vehicle.status})."
            )
        if payload.weight > vehicle.capacity_kg:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Cargo weight ({payload.weight} kg) exceeds vehicle payload capacity ({vehicle.capacity_kg} kg)."
            )

    # 3. Validate Driver Availability (if driver assigned)
    driver = None
    if payload.driver_id:
        driver = db.query(Driver).filter(Driver.id == payload.driver_id).with_for_update().first()
        if not driver:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Selected driver not found.")
        if driver.status != "ACTIVE":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Driver {driver.name} is not ready for dispatch (Current status: {driver.status})."
            )

    shipment_id = str(uuid.uuid4())
    tracking_num = generate_tracking_number(db)
    initial_status = "BOOKED" if (payload.driver_id and payload.vehicle_id) else "PENDING"

    try:
        # Create shipment
        new_shipment = Shipment(
            id=shipment_id,
            tracking_number=tracking_num,
            customer_id=payload.customer_id,
            origin_address=payload.origin_address,
            destination_address=payload.destination_address,
            scheduled_pickup=payload.scheduled_pickup or datetime.utcnow(),
            scheduled_delivery=payload.scheduled_delivery,
            status=initial_status,
            weight=payload.weight,
            volume=payload.volume,
            cargo_type=payload.cargo_type or "General Goods",
            route_id=payload.route_id,
            driver_id=payload.driver_id,
            vehicle_id=payload.vehicle_id
        )
        db.add(new_shipment)

        # Update vehicle & driver statuses
        if vehicle:
            vehicle.status = "IN_USE"
        if driver:
            driver.status = "ON_DUTY"

        # Generate Billing Record if billing_amount provided
        if payload.billing_amount and payload.billing_amount > 0:
            tax = round(payload.billing_amount * Decimal("0.18"), 2)
            invoice_num = f"INV-{datetime.utcnow().strftime('%Y%m%d')}-{shipment_id[:6].upper()}"
            invoice = Billing(
                id=str(uuid.uuid4()),
                invoice_number=invoice_num,
                shipment_id=shipment_id,
                customer_id=payload.customer_id,
                amount=payload.billing_amount,
                tax_amount=tax,
                currency="INR",
                billing_date=date.today(),
                status="UNPAID",
                payment_method=payload.payment_method
            )
            db.add(invoice)

        # Commit transaction
        db.commit()
        db.refresh(new_shipment)
        return new_shipment

    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to book shipment: {str(e)}"
        )

@router.post("/{shipment_id}/status", response_model=ShipmentResponse)
def update_shipment_status(
    shipment_id: str,
    payload: ShipmentStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """
    Transition shipment status with atomic tracking log and fleet release.
    Calls MySQL Stored Procedure `sp_update_shipment_status`.
    """
    shipment = db.query(Shipment).filter(Shipment.id == shipment_id).first()
    if not shipment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shipment not found.")

    conn = db.connection().connection
    cursor = conn.cursor()
    try:
        # Call stored procedure
        cursor.callproc(
            "sp_update_shipment_status",
            (shipment_id, payload.status, payload.location, payload.notes or "", current_user.username, 0)
        )
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Database procedure failed: {str(e)}")
    finally:
        cursor.close()

    db.refresh(shipment)
    return shipment

@router.post("/{shipment_id}/cancel", response_model=ShipmentResponse)
def cancel_shipment(
    shipment_id: str,
    reason: Optional[str] = Query("Customer requested cancellation", description="Cancellation reason"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Cancel shipment and release allocated vehicle and driver."""
    shipment = db.query(Shipment).filter(Shipment.id == shipment_id).first()
    if not shipment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shipment not found.")

    if shipment.status in ["DELIVERED", "CANCELLED"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Cannot cancel shipment in '{shipment.status}' status.")

    conn = db.connection().connection
    cursor = conn.cursor()
    try:
        cursor.callproc(
            "sp_update_shipment_status",
            (shipment_id, "CANCELLED", "Central Operations", f"Cancelled by {current_user.username}: {reason}", current_user.username, 0)
        )
        db.commit()
    finally:
        cursor.close()

    db.refresh(shipment)
    return shipment

@router.put("/{shipment_id}", response_model=ShipmentResponse)
def edit_shipment(
    shipment_id: str,
    payload: ShipmentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Edit shipment parameters (origin, destination, weight, route, etc.)."""
    shipment = db.query(Shipment).filter(Shipment.id == shipment_id).first()
    if not shipment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shipment not found.")

    if shipment.status == "DELIVERED":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot edit a delivered shipment.")

    update_data = payload.dict(exclude_unset=True)
    for field, val in update_data.items():
        setattr(shipment, field, val)

    db.commit()
    db.refresh(shipment)
    return shipment
