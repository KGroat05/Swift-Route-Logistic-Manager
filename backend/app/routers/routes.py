"""
Route Management Router for Swift Route Logistics Manager.
Provides CRUD operations for routes and distance calculations.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import Route, User
from ..schemas import RouteCreate, RouteUpdate, RouteResponse
from ..auth import get_current_user, require_role

router = APIRouter(prefix="/api/v1/routes", tags=["Route & Distance Management"])

@router.get("", response_model=List[RouteResponse])
def get_routes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve all predefined logistics transit routes."""
    return db.query(Route).order_by(Route.estimated_distance_km.asc()).all()

@router.get("/{route_id}", response_model=RouteResponse)
def get_route(
    route_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve single route details by UUID."""
    route = db.query(Route).filter(Route.id == route_id).first()
    if not route:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found.")
    return route

@router.post("", response_model=RouteResponse, status_code=status.HTTP_201_CREATED)
def create_route(
    payload: RouteCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Create a new route profile."""
    route = Route(
        name=payload.name,
        start_location=payload.start_location,
        end_location=payload.end_location,
        estimated_distance_km=payload.estimated_distance_km,
        estimated_time_minutes=payload.estimated_time_minutes,
        toll_charges=payload.toll_charges or 0.00
    )
    db.add(route)
    db.commit()
    db.refresh(route)
    return route

@router.put("/{route_id}", response_model=RouteResponse)
def update_route(
    route_id: str,
    payload: RouteUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Update route parameters."""
    route = db.query(Route).filter(Route.id == route_id).first()
    if not route:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found.")

    update_data = payload.dict(exclude_unset=True)
    for field, val in update_data.items():
        setattr(route, field, val)

    db.commit()
    db.refresh(route)
    return route

@router.delete("/{route_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_route(
    route_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN"]))
):
    """Delete a route."""
    route = db.query(Route).filter(Route.id == route_id).first()
    if not route:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found.")

    db.delete(route)
    db.commit()
    return None
