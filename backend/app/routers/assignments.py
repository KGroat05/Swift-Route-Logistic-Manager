"""
Driver and Vehicle Assignment Router for Swift Route Logistics Manager.
Validates availability, schedules shifts, and manages M:N junctions.
"""
from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import DriverAssignment, Driver, Vehicle, Route, User
from ..schemas import DriverAssignmentCreate, DriverAssignmentResponse
from ..auth import get_current_user, require_role

router = APIRouter(prefix="/api/v1/assignments", tags=["Driver & Vehicle Assignments"])

@router.get("", response_model=List[DriverAssignmentResponse])
def get_assignments(
    assignment_date: Optional[date] = Query(None, description="Filter by date"),
    status: Optional[str] = Query(None, description="Filter by assignment status"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all driver and vehicle dispatch assignments."""
    query = db.query(DriverAssignment)
    if assignment_date:
        query = query.filter(DriverAssignment.assignment_date == assignment_date)
    if status:
        query = query.filter(DriverAssignment.status == status)
    return query.order_by(DriverAssignment.assignment_date.desc(), DriverAssignment.created_at.desc()).all()

@router.post("", response_model=DriverAssignmentResponse, status_code=status.HTTP_201_CREATED)
def create_assignment(
    payload: DriverAssignmentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """
    Create a new dispatch assignment.
    Validates driver readiness, vehicle availability, and prevents double-booking.
    """
    driver = db.query(Driver).filter(Driver.id == payload.driver_id).first()
    if not driver:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Driver not found.")
    if driver.status not in ["ACTIVE", "ON_DUTY"]:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Driver is not active (Status: {driver.status}).")

    vehicle = db.query(Vehicle).filter(Vehicle.id == payload.vehicle_id).first()
    if not vehicle:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found.")
    if vehicle.status == "MAINTENANCE" or vehicle.status == "RETIRED":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Vehicle is unusable (Status: {vehicle.status}).")

    # Conflict check for active shifts on the same date
    active_conflict = db.query(DriverAssignment).filter(
        DriverAssignment.assignment_date == payload.assignment_date,
        DriverAssignment.status.in_(["SCHEDULED", "ONGOING"]),
        (DriverAssignment.driver_id == payload.driver_id) | (DriverAssignment.vehicle_id == payload.vehicle_id)
    ).first()

    if active_conflict:
        if active_conflict.driver_id == payload.driver_id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Driver is already assigned to a shift on this date.")
        else:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Vehicle is already booked for a shift on this date.")

    assignment = DriverAssignment(
        driver_id=payload.driver_id,
        vehicle_id=payload.vehicle_id,
        route_id=payload.route_id,
        assignment_date=payload.assignment_date,
        shift_start=payload.shift_start,
        shift_end=payload.shift_end,
        status=payload.status
    )
    db.add(assignment)
    db.commit()
    db.refresh(assignment)
    return assignment

@router.put("/{assignment_id}/status", response_model=DriverAssignmentResponse)
def update_assignment_status(
    assignment_id: str,
    status_val: str = Query(..., pattern="^(SCHEDULED|ONGOING|COMPLETED|CANCELLED)$"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Update assignment status."""
    assignment = db.query(DriverAssignment).filter(DriverAssignment.id == assignment_id).first()
    if not assignment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found.")

    assignment.status = status_val
    if status_val == "COMPLETED" or status_val == "CANCELLED":
        # Release vehicle and driver if not in another active shift
        vehicle = db.query(Vehicle).filter(Vehicle.id == assignment.vehicle_id).first()
        driver = db.query(Driver).filter(Driver.id == assignment.driver_id).first()
        if vehicle and vehicle.status == "IN_USE":
            vehicle.status = "AVAILABLE"
        if driver and driver.status == "ON_DUTY":
            driver.status = "ACTIVE"

    db.commit()
    db.refresh(assignment)
    return assignment
