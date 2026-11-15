"""
Customer Management Router for Swift Route Logistics Manager.
Provides CRUD operations, search filters, and shipment histories.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import Customer, User, Shipment
from ..schemas import CustomerCreate, CustomerUpdate, CustomerResponse
from ..auth import get_current_user, require_role

router = APIRouter(prefix="/api/v1/customers", tags=["Customer Management"])

@router.get("", response_model=List[CustomerResponse])
def get_customers(
    search: Optional[str] = Query(None, description="Search by name, city, or email"),
    city: Optional[str] = Query(None, description="Filter by city"),
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List all customers with optional search and city filters."""
    query = db.query(Customer)
    if search:
        s = f"%{search}%"
        query = query.filter(
            (Customer.name.ilike(s)) |
            (Customer.contact_email.ilike(s)) |
            (Customer.contact_phone.ilike(s)) |
            (Customer.city.ilike(s))
        )
    if city:
        query = query.filter(Customer.city == city)
    return query.order_by(Customer.name.asc()).offset(skip).limit(limit).all()

@router.get("/{customer_id}", response_model=CustomerResponse)
def get_customer(
    customer_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve single customer by UUID."""
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found.")
    return customer

@router.post("", response_model=CustomerResponse, status_code=status.HTTP_201_CREATED)
def create_customer(
    payload: CustomerCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Register a new customer (Admin or Dispatcher only)."""
    if db.query(Customer).filter(Customer.contact_email == payload.contact_email).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Contact email is already registered.")

    customer = Customer(
        name=payload.name,
        contact_name=payload.contact_name,
        contact_email=payload.contact_email,
        contact_phone=payload.contact_phone,
        address=payload.address,
        city=payload.city or "Chennai",
        state=payload.state or "Tamil Nadu",
        postal_code=payload.postal_code or "600001"
    )
    db.add(customer)
    db.commit()
    db.refresh(customer)
    return customer

@router.put("/{customer_id}", response_model=CustomerResponse)
def update_customer(
    customer_id: str,
    payload: CustomerUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """Update customer details."""
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found.")

    if payload.contact_email and payload.contact_email != customer.contact_email:
        if db.query(Customer).filter(Customer.contact_email == payload.contact_email).first():
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Contact email is already registered.")

    update_data = payload.dict(exclude_unset=True)
    for field, val in update_data.items():
        setattr(customer, field, val)

    db.commit()
    db.refresh(customer)
    return customer

@router.delete("/{customer_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_customer(
    customer_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN"]))
):
    """Delete customer record (Admin only; restricted if foreign key shipments exist)."""
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Customer not found.")

    active_shipments = db.query(Shipment).filter(Shipment.customer_id == customer_id).count()
    if active_shipments > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot delete customer. There are {active_shipments} associated shipments."
        )

    db.delete(customer)
    db.commit()
    return None
