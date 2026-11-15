"""
Pydantic Schemas for Swift Route Logistics Manager.
Request validation and response models using Pydantic v2.
"""
from typing import Optional, Any, List, Dict
from datetime import datetime, date
from decimal import Decimal
from pydantic import BaseModel, EmailStr, Field

# ---------------------------------------------------------------------
# User & Auth Schemas
# ---------------------------------------------------------------------
class UserLogin(BaseModel):
    username: str
    password: str

class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(..., min_length=6)
    full_name: str = Field(..., min_length=2, max_length=100)
    role: str = Field(default="VIEWER", pattern="^(ADMIN|DISPATCHER|VIEWER)$")

class UserResponse(BaseModel):
    id: str
    username: str
    email: str
    full_name: str
    role: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse

class TokenData(BaseModel):
    username: Optional[str] = None
    role: Optional[str] = None

# ---------------------------------------------------------------------
# Customer Schemas
# ---------------------------------------------------------------------
class CustomerBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=255)
    contact_name: Optional[str] = None
    contact_email: EmailStr
    contact_phone: str = Field(..., min_length=5, max_length=50)
    address: str
    city: Optional[str] = "Chennai"
    state: Optional[str] = "Tamil Nadu"
    postal_code: Optional[str] = "600001"

class CustomerCreate(CustomerBase):
    pass

class CustomerUpdate(BaseModel):
    name: Optional[str] = None
    contact_name: Optional[str] = None
    contact_email: Optional[EmailStr] = None
    contact_phone: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    postal_code: Optional[str] = None

class CustomerResponse(CustomerBase):
    id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# ---------------------------------------------------------------------
# Route Schemas
# ---------------------------------------------------------------------
class RouteBase(BaseModel):
    name: str
    start_location: str
    end_location: str
    estimated_distance_km: Decimal = Field(..., gt=0)
    estimated_time_minutes: int = Field(..., gt=0)
    toll_charges: Optional[Decimal] = Decimal("0.00")

class RouteCreate(RouteBase):
    pass

class RouteUpdate(BaseModel):
    name: Optional[str] = None
    start_location: Optional[str] = None
    end_location: Optional[str] = None
    estimated_distance_km: Optional[Decimal] = None
    estimated_time_minutes: Optional[int] = None
    toll_charges: Optional[Decimal] = None

class RouteResponse(RouteBase):
    id: str
    created_at: datetime

    class Config:
        from_attributes = True

# ---------------------------------------------------------------------
# Vehicle Schemas
# ---------------------------------------------------------------------
class VehicleBase(BaseModel):
    license_plate: str
    model: str
    vehicle_type: str = Field(default="LIGHT_TRUCK", pattern="^(MINI_VAN|LIGHT_TRUCK|HEAVY_TRUCK|CONTAINER)$")
    capacity_kg: Decimal = Field(..., gt=0)
    capacity_m3: Optional[Decimal] = None
    status: str = Field(default="AVAILABLE", pattern="^(AVAILABLE|IN_USE|MAINTENANCE|RETIRED)$")
    last_maintenance_date: Optional[date] = None

class VehicleCreate(VehicleBase):
    pass

class VehicleUpdate(BaseModel):
    model: Optional[str] = None
    vehicle_type: Optional[str] = None
    capacity_kg: Optional[Decimal] = None
    capacity_m3: Optional[Decimal] = None
    status: Optional[str] = None
    last_maintenance_date: Optional[date] = None

class VehicleResponse(VehicleBase):
    id: str
    created_at: datetime

    class Config:
        from_attributes = True

# ---------------------------------------------------------------------
# Driver Schemas
# ---------------------------------------------------------------------
class DriverBase(BaseModel):
    name: str
    license_number: str
    phone: str
    email: EmailStr
    status: str = Field(default="ACTIVE", pattern="^(ACTIVE|ON_DUTY|ON_LEAVE|SUSPENDED)$")
    hired_date: date
    experience_years: Optional[int] = 1

class DriverCreate(DriverBase):
    pass

class DriverUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[EmailStr] = None
    status: Optional[str] = None
    experience_years: Optional[int] = None

class DriverResponse(DriverBase):
    id: str
    created_at: datetime

    class Config:
        from_attributes = True

# ---------------------------------------------------------------------
# Driver Assignment Schemas
# ---------------------------------------------------------------------
class DriverAssignmentBase(BaseModel):
    driver_id: str
    vehicle_id: str
    route_id: Optional[str] = None
    assignment_date: date
    shift_start: Optional[datetime] = None
    shift_end: Optional[datetime] = None
    status: str = Field(default="SCHEDULED", pattern="^(SCHEDULED|ONGOING|COMPLETED|CANCELLED)$")

class DriverAssignmentCreate(DriverAssignmentBase):
    pass

class DriverAssignmentResponse(DriverAssignmentBase):
    id: str
    created_at: datetime
    driver: Optional[DriverResponse] = None
    vehicle: Optional[VehicleResponse] = None
    route: Optional[RouteResponse] = None

    class Config:
        from_attributes = True

# ---------------------------------------------------------------------
# Tracking Event Schemas
# ---------------------------------------------------------------------
class TrackingEventBase(BaseModel):
    location: str
    status: str
    notes: Optional[str] = None

class TrackingEventCreate(TrackingEventBase):
    shipment_id: str
    created_by: Optional[str] = "DISPATCHER"

class TrackingEventResponse(TrackingEventBase):
    id: str
    shipment_id: str
    event_time: datetime
    created_by: str

    class Config:
        from_attributes = True

# ---------------------------------------------------------------------
# Billing / Invoice Schemas
# ---------------------------------------------------------------------
class BillingBase(BaseModel):
    shipment_id: str
    customer_id: str
    amount: Decimal = Field(..., ge=0)
    tax_amount: Optional[Decimal] = Decimal("0.00")
    currency: Optional[str] = "INR"
    billing_date: date
    due_date: Optional[date] = None
    status: str = Field(default="UNPAID", pattern="^(UNPAID|PARTIAL|PAID|OVERDUE|CANCELLED)$")
    payment_method: Optional[str] = None

class BillingCreate(BillingBase):
    pass

class PaymentUpdate(BaseModel):
    status: str = Field(..., pattern="^(UNPAID|PARTIAL|PAID|OVERDUE|CANCELLED)$")
    payment_method: Optional[str] = Field(None, pattern="^(NEFT|UPI|CREDIT_CARD|CASH|CHEQUE)$")

class BillingResponse(BillingBase):
    id: str
    invoice_number: str
    total_amount: Optional[Decimal] = None
    paid_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True

# ---------------------------------------------------------------------
# Shipment Schemas
# ---------------------------------------------------------------------
class ShipmentBase(BaseModel):
    customer_id: str
    origin_address: str
    destination_address: str
    scheduled_pickup: Optional[datetime] = None
    scheduled_delivery: Optional[datetime] = None
    weight: Decimal = Field(..., gt=0)
    volume: Optional[Decimal] = None
    cargo_type: Optional[str] = "General Goods"
    route_id: Optional[str] = None
    driver_id: Optional[str] = None
    vehicle_id: Optional[str] = None

class ShipmentCreate(ShipmentBase):
    billing_amount: Optional[Decimal] = Decimal("0.00")
    payment_method: Optional[str] = None

class ShipmentUpdate(BaseModel):
    origin_address: Optional[str] = None
    destination_address: Optional[str] = None
    scheduled_pickup: Optional[datetime] = None
    scheduled_delivery: Optional[datetime] = None
    weight: Optional[Decimal] = None
    volume: Optional[Decimal] = None
    cargo_type: Optional[str] = None
    route_id: Optional[str] = None
    driver_id: Optional[str] = None
    vehicle_id: Optional[str] = None

class ShipmentStatusUpdate(BaseModel):
    status: str = Field(..., pattern="^(PENDING|BOOKED|IN_TRANSIT|OUT_FOR_DELIVERY|DELIVERED|CANCELLED)$")
    location: str
    notes: Optional[str] = None

class ShipmentResponse(ShipmentBase):
    id: str
    tracking_number: str
    actual_delivery: Optional[datetime] = None
    status: str
    created_at: datetime
    updated_at: datetime
    customer: Optional[CustomerResponse] = None
    route: Optional[RouteResponse] = None
    driver: Optional[DriverResponse] = None
    vehicle: Optional[VehicleResponse] = None

    class Config:
        from_attributes = True

class ShipmentDetailResponse(ShipmentResponse):
    tracking_events: List[TrackingEventResponse] = []
    invoice: Optional[BillingResponse] = None

# ---------------------------------------------------------------------
# Inventory Schemas
# ---------------------------------------------------------------------
class InventoryBase(BaseModel):
    item_code: str
    item_name: str
    description: Optional[str] = None
    category: Optional[str] = "Packaging Material"
    quantity: int = Field(..., ge=0)
    unit_of_measure: Optional[str] = "Units"
    reorder_level: int = Field(default=20, ge=0)
    unit_cost: Decimal = Field(default=Decimal("0.00"), ge=0)
    location: Optional[str] = "Warehouse Central - Chennai"

class InventoryCreate(InventoryBase):
    pass

class InventoryUpdate(BaseModel):
    item_name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    quantity: Optional[int] = None
    reorder_level: Optional[int] = None
    unit_cost: Optional[Decimal] = None
    location: Optional[str] = None

class InventoryResponse(InventoryBase):
    id: str
    last_updated: datetime

    class Config:
        from_attributes = True

# ---------------------------------------------------------------------
# Dashboard & Analytics Schemas
# ---------------------------------------------------------------------
class DashboardKPIs(BaseModel):
    total_customers: int
    total_shipments: int
    active_shipments: int
    delivered_shipments: int
    active_drivers: int
    available_vehicles: int
    total_revenue_inr: Decimal
    pending_invoices_count: int
    low_stock_items_count: int

# ---------------------------------------------------------------------
# SQL Lab & Concurrency Schemas
# ---------------------------------------------------------------------
class SQLQueryRequest(BaseModel):
    query: str

class SQLQueryResponse(BaseModel):
    columns: List[str]
    rows: List[Dict[str, Any]]
    row_count: int
    execution_time_ms: float

class ConcurrencySimulationRequest(BaseModel):
    vehicle_id: str
    scenario: str = "PESSIMISTIC_LOCK_TEST"
