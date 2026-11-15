"""
Vehicle Fleet Management Router for Swift Route Logistics Manager.
Provides CRUD operations, status filters, and capacity checks.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import Vehicle, User
from ..schemas import VehicleCreate, VehicleUpdate, VehicleResponse
from ..auth import get_current_user, require_role

router = APIRouter(prefix="/api/v1/vehicles", tags=["Fleet & Vehicle Management"])

@router.get("", response_model=List[VehicleResponse])
def get_vehicles(
    status: Optional[str] = Query(None, description="Filter by status (AVAILABLE, IN_USE, MAINTENANCE, RETIRED)"),
    vehicle_type: Optional[str] = Query(None, description="Filter by vehicle type"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve all vehicles with optional status and type filters."""
    query = db.query(Vehicle)
    if status:
        query = query.filter(Vehicle.status == status)
    if vehicle_type:
        query = query.filter(Vehicle.vehicle_type == vehicle_type)
    return query.order_by(Vehicle.license_plate.asc()).all()

@router.get("/available", response_model=List[VehicleResponse])
def get_available_vehicles(
    min_capacity_kg: Optional[float] = Query(None, description="Minimum payload capacity required"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve currently available vehicles suitable for dispatch."""
    query = db.query(Vehicle).filter(Vehicle.status == "AVAILABLE")
    if min_capacity_kg is not None:
        query = query.filter(Vehicle.capacity_kg >= min_capacity_kg)
    return query.order_by(Vehicle.capacity_kg.asc()).all()

@router.get("/{vehicle_id}", response_model=VehicleResponse)
def get_vehicle(
    vehicle_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve single vehicle by UUID."""
    vehicle = db.query(Vehicle).filter(Vehicle.id == vehicle_id).first()
    if not vehicle:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found.")
    return vehicle

@router.post("", response_model=VehicleResponse, status_code=status.HTTP_201_CREATED)
def create_vehicle(
    payload: VehicleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Register a new fleet vehicle."""
    if db.query(Vehicle).filter(Vehicle.license_plate == payload.license_plate).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="License plate already registered.")

    vehicle = Vehicle(
        license_plate=payload.license_plate,
        model=payload.model,
        vehicle_type=payload.vehicle_type,
        capacity_kg=payload.capacity_kg,
        capacity_m3=payload.capacity_m3,
        status=payload.status,
        last_maintenance_date=payload.last_maintenance_date
    )
    db.add(vehicle)
    db.commit()
    db.refresh(vehicle)
    return vehicle

@router.put("/{vehicle_id}", response_model=VehicleResponse)
def update_vehicle(
    vehicle_id: str,
    payload: VehicleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Update vehicle specifications or status."""
    vehicle = db.query(Vehicle).filter(Vehicle.id == vehicle_id).first()
    if not vehicle:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found.")

    update_data = payload.dict(exclude_unset=True)
    for field, val in update_data.items():
        setattr(vehicle, field, val)

    db.commit()
    db.refresh(vehicle)
    return vehicle

@router.delete("/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_vehicle(
    vehicle_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN"]))
):
    """Delete vehicle (Admin only)."""
    vehicle = db.query(Vehicle).filter(Vehicle.id == vehicle_id).first()
    if not vehicle:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found.")

    db.delete(vehicle)
    db.commit()
    return None
