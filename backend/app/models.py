"""
SQLAlchemy ORM Models for Swift Route Logistics Manager.
Maps to MySQL 8.4 LTS normalized relational database schema.
"""
import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Integer, Numeric, DateTime, Date, Boolean, Text,
    ForeignKey, Enum, CheckConstraint
)
from sqlalchemy.schema import FetchedValue
from sqlalchemy.dialects.mysql import JSON
from sqlalchemy.orm import relationship
from .database import Base

def generate_uuid():
    return str(uuid.uuid4())

class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(100), nullable=False)
    role = Column(Enum('ADMIN', 'DISPATCHER', 'VIEWER', name='user_role_enum'), nullable=False, default='VIEWER')
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

class Customer(Base):
    __tablename__ = "customers"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(255), nullable=False)
    contact_name = Column(String(255))
    contact_email = Column(String(255), unique=True, nullable=False, index=True)
    contact_phone = Column(String(50), nullable=False)
    address = Column(Text, nullable=False)
    city = Column(String(100), default='Chennai')
    state = Column(String(100), default='Tamil Nadu')
    postal_code = Column(String(20), default='600001')
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    shipments = relationship("Shipment", back_populates="customer")
    invoices = relationship("Billing", back_populates="customer")

class Route(Base):
    __tablename__ = "routes"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(100), nullable=False)
    start_location = Column(String(255), nullable=False)
    end_location = Column(String(255), nullable=False)
    estimated_distance_km = Column(Numeric(10, 2), nullable=False)
    estimated_time_minutes = Column(Integer, nullable=False)
    toll_charges = Column(Numeric(10, 2), default=0.00, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    shipments = relationship("Shipment", back_populates="route")
    assignments = relationship("DriverAssignment", back_populates="route")

class Vehicle(Base):
    __tablename__ = "vehicles"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    license_plate = Column(String(20), unique=True, nullable=False, index=True)
    model = Column(String(100), nullable=False)
    vehicle_type = Column(
        Enum('MINI_VAN', 'LIGHT_TRUCK', 'HEAVY_TRUCK', 'CONTAINER', name='vehicle_type_enum'),
        nullable=False, default='LIGHT_TRUCK'
    )
    capacity_kg = Column(Numeric(10, 2), nullable=False)
    capacity_m3 = Column(Numeric(10, 2))
    status = Column(
        Enum('AVAILABLE', 'IN_USE', 'MAINTENANCE', 'RETIRED', name='vehicle_status_enum'),
        nullable=False, default='AVAILABLE', index=True
    )
    last_maintenance_date = Column(Date)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    shipments = relationship("Shipment", back_populates="vehicle")
    assignments = relationship("DriverAssignment", back_populates="vehicle")

class Driver(Base):
    __tablename__ = "drivers"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(100), nullable=False)
    license_number = Column(String(50), unique=True, nullable=False, index=True)
    phone = Column(String(20), nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    status = Column(
        Enum('ACTIVE', 'ON_DUTY', 'ON_LEAVE', 'SUSPENDED', name='driver_status_enum'),
        nullable=False, default='ACTIVE', index=True
    )
    hired_date = Column(Date, nullable=False)
    experience_years = Column(Integer, default=1)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    shipments = relationship("Shipment", back_populates="driver")
    assignments = relationship("DriverAssignment", back_populates="driver")

class DriverAssignment(Base):
    __tablename__ = "driver_assignments"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    driver_id = Column(String(36), ForeignKey("drivers.id"), nullable=False, index=True)
    vehicle_id = Column(String(36), ForeignKey("vehicles.id"), nullable=False, index=True)
    route_id = Column(String(36), ForeignKey("routes.id"), nullable=True)
    assignment_date = Column(Date, nullable=False)
    shift_start = Column(DateTime)
    shift_end = Column(DateTime)
    status = Column(
        Enum('SCHEDULED', 'ONGOING', 'COMPLETED', 'CANCELLED', name='assignment_status_enum'),
        nullable=False, default='SCHEDULED'
    )
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    driver = relationship("Driver", back_populates="assignments")
    vehicle = relationship("Vehicle", back_populates="assignments")
    route = relationship("Route", back_populates="assignments")

class Shipment(Base):
    __tablename__ = "shipments"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    tracking_number = Column(String(50), unique=True, nullable=False, index=True)
    customer_id = Column(String(36), ForeignKey("customers.id"), nullable=False, index=True)
    origin_address = Column(Text, nullable=False)
    destination_address = Column(Text, nullable=False)
    scheduled_pickup = Column(DateTime)
    scheduled_delivery = Column(DateTime)
    actual_delivery = Column(DateTime)
    status = Column(
        Enum('PENDING', 'BOOKED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED', name='shipment_status_enum'),
        nullable=False, default='PENDING', index=True
    )
    weight = Column(Numeric(10, 3), nullable=False)
    volume = Column(Numeric(10, 3))
    cargo_type = Column(String(100), default='General Goods')
    route_id = Column(String(36), ForeignKey("routes.id"), nullable=True)
    driver_id = Column(String(36), ForeignKey("drivers.id"), nullable=True)
    vehicle_id = Column(String(36), ForeignKey("vehicles.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    customer = relationship("Customer", back_populates="shipments")
    route = relationship("Route", back_populates="shipments")
    driver = relationship("Driver", back_populates="shipments")
    vehicle = relationship("Vehicle", back_populates="shipments")
    tracking_events = relationship("TrackingEvent", back_populates="shipment", cascade="all, delete-orphan", order_by="TrackingEvent.event_time.asc()")
    invoice = relationship("Billing", back_populates="shipment", uselist=False)

class TrackingEvent(Base):
    __tablename__ = "tracking_events"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    shipment_id = Column(String(36), ForeignKey("shipments.id", ondelete="CASCADE"), nullable=False, index=True)
    event_time = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    location = Column(String(255), nullable=False)
    status = Column(String(100), nullable=False)
    notes = Column(Text)
    created_by = Column(String(50), default='SYSTEM')

    shipment = relationship("Shipment", back_populates="tracking_events")

class Billing(Base):
    __tablename__ = "invoices"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    invoice_number = Column(String(100), unique=True, nullable=False, index=True)
    shipment_id = Column(String(36), ForeignKey("shipments.id"), nullable=False)
    customer_id = Column(String(36), ForeignKey("customers.id"), nullable=False, index=True)
    amount = Column(Numeric(12, 2), nullable=False)
    tax_amount = Column(Numeric(10, 2), default=0.00, nullable=False)
    total_amount = Column(Numeric(12, 2), server_default=FetchedValue())  # Stored generated column in MySQL
    currency = Column(String(3), default='INR', nullable=False)
    billing_date = Column(Date, nullable=False)
    due_date = Column(Date)
    status = Column(
        Enum('UNPAID', 'PARTIAL', 'PAID', 'OVERDUE', 'CANCELLED', name='billing_status_enum'),
        nullable=False, default='UNPAID', index=True
    )
    payment_method = Column(
        Enum('NEFT', 'UPI', 'CREDIT_CARD', 'CASH', 'CHEQUE', name='payment_method_enum'),
        nullable=True
    )
    paid_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    shipment = relationship("Shipment", back_populates="invoice")
    customer = relationship("Customer", back_populates="invoices")

class Inventory(Base):
    __tablename__ = "inventory"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    item_code = Column(String(50), unique=True, nullable=False, index=True)
    item_name = Column(String(255), nullable=False)
    description = Column(Text)
    category = Column(String(100), default='Packaging Material')
    quantity = Column(Integer, default=0, nullable=False)
    unit_of_measure = Column(String(20), default='Units')
    reorder_level = Column(Integer, default=20, nullable=False)
    unit_cost = Column(Numeric(10, 2), default=0.00, nullable=False)
    location = Column(String(100), default='Warehouse Central - Chennai', nullable=False)
    last_updated = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

class PartnerIntegration(Base):
    __tablename__ = "partner_integrations"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    partner_name = Column(String(100), nullable=False)
    integration_type = Column(
        Enum('TRACKING_API', 'BILLING_GATEWAY', '3PL_DISPATCH', 'SMS_NOTIFICATION', name='integration_type_enum'),
        nullable=False
    )
    api_endpoint = Column(String(500))
    auth_token = Column(String(255))
    status = Column(Enum('ACTIVE', 'INACTIVE', 'ERROR', name='partner_status_enum'), default='ACTIVE')
    last_sync = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class Analytics(Base):
    __tablename__ = "analytics_reports"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    report_type = Column(String(100), nullable=False, index=True)
    generated_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    data = Column(JSON, nullable=False)
    related_shipment_id = Column(String(36), nullable=True)
    related_driver_id = Column(String(36), nullable=True)
    related_vehicle_id = Column(String(36), nullable=True)
    related_event_id = Column(String(36), nullable=True)
