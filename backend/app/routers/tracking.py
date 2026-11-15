"""
Shipment Milestone Tracking Router for Swift Route Logistics Manager.
Provides chronological timeline event queries and manual event additions.
"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import TrackingEvent, Shipment, User
from ..schemas import TrackingEventCreate, TrackingEventResponse
from ..auth import get_current_user, require_role

router = APIRouter(prefix="/api/v1/tracking", tags=["Tracking Timeline"])

@router.get("/{shipment_id}", response_model=List[TrackingEventResponse])
def get_tracking_timeline(
    shipment_id: str,
    db: Session = Depends(get_db)
):
    """Retrieve full chronological milestone timeline for a shipment."""
    shipment = db.query(Shipment).filter(Shipment.id == shipment_id).first()
    if not shipment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shipment not found.")

    return db.query(TrackingEvent).filter(
        TrackingEvent.shipment_id == shipment_id
    ).order_by(TrackingEvent.event_time.asc()).all()

@router.post("", response_model=TrackingEventResponse, status_code=status.HTTP_201_CREATED)
def add_tracking_event(
    payload: TrackingEventCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Manually log a checkpoint tracking event."""
    shipment = db.query(Shipment).filter(Shipment.id == payload.shipment_id).first()
    if not shipment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shipment not found.")

    event = TrackingEvent(
        shipment_id=payload.shipment_id,
        location=payload.location,
        status=payload.status,
        notes=payload.notes,
        created_by=current_user.username
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event
