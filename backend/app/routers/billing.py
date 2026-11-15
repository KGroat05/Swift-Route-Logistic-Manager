"""
Billing & Invoicing Router for Swift Route Logistics Manager.
Handles invoice records, payment processing, tax computations, and aging status.
"""
from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import Billing, User
from ..schemas import BillingResponse, PaymentUpdate
from ..auth import get_current_user, require_role

router = APIRouter(prefix="/api/v1/billing", tags=["Billing & Invoices"])

@router.get("", response_model=List[BillingResponse])
def get_invoices(
    status: Optional[str] = Query(None, description="Filter by status (UNPAID, PARTIAL, PAID, OVERDUE, CANCELLED)"),
    customer_id: Optional[str] = Query(None, description="Filter by customer UUID"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve all invoices with status and customer filters."""
    query = db.query(Billing)
    if status:
        query = query.filter(Billing.status == status)
    if customer_id:
        query = query.filter(Billing.customer_id == customer_id)
    return query.order_by(Billing.billing_date.desc()).all()

@router.get("/{invoice_id}", response_model=BillingResponse)
def get_invoice(
    invoice_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve single invoice details by UUID."""
    invoice = db.query(Billing).filter(Billing.id == invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invoice not found.")
    return invoice

@router.put("/{invoice_id}/payment", response_model=BillingResponse)
def update_payment_status(
    invoice_id: str,
    payload: PaymentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["ADMIN", "DISPATCHER"]))
):
    """
    Update payment status (e.g. mark PAID with payment method).
    Triggers `trg_invoice_payment_sync` in MySQL to auto-populate `paid_at`.
    """
    invoice = db.query(Billing).filter(Billing.id == invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invoice not found.")

    invoice.status = payload.status
    if payload.payment_method:
        invoice.payment_method = payload.payment_method
    if payload.status == "PAID" and not invoice.paid_at:
        invoice.paid_at = datetime.utcnow()

    db.commit()
    db.refresh(invoice)
    return invoice
