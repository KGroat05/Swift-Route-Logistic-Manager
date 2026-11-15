-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Relational Database DDL Schema: 01_schema.sql
-- Engine: MySQL 8.4 LTS (InnoDB Storage Engine)
-- =====================================================================

USE swiftroute;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS analytics_reports;
DROP TABLE IF EXISTS partner_integrations;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS invoices;
DROP TABLE IF EXISTS tracking_events;
DROP TABLE IF EXISTS driver_assignments;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS routes;
DROP TABLE IF EXISTS vehicles;
DROP TABLE IF EXISTS drivers;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. Table: users
-- Implements Authentication and Role-Based Authorization (Admin, Dispatcher, Viewer)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id VARCHAR(36) NOT NULL,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role ENUM('ADMIN', 'DISPATCHER', 'VIEWER') NOT NULL DEFAULT 'VIEWER',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_users PRIMARY KEY (id),
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT uq_users_email UNIQUE (email)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. Table: customers
-- Corporate clients and personal consignors placing delivery orders
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    id VARCHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL,
    contact_name VARCHAR(255) NULL,
    contact_email VARCHAR(255) NOT NULL,
    contact_phone VARCHAR(50) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL DEFAULT 'Chennai',
    state VARCHAR(100) NOT NULL DEFAULT 'Tamil Nadu',
    postal_code VARCHAR(20) NOT NULL DEFAULT '600001',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_customers PRIMARY KEY (id),
    CONSTRAINT uq_customers_email UNIQUE (contact_email)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. Table: drivers
-- Certified commercial transport operators and drivers
-- ---------------------------------------------------------------------
CREATE TABLE drivers (
    id VARCHAR(36) NOT NULL,
    name VARCHAR(100) NOT NULL,
    license_number VARCHAR(50) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(255) NOT NULL,
    status ENUM('ACTIVE', 'ON_DUTY', 'ON_LEAVE', 'SUSPENDED') NOT NULL DEFAULT 'ACTIVE',
    hired_date DATE NOT NULL,
    experience_years INT NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_drivers PRIMARY KEY (id),
    CONSTRAINT uq_drivers_license UNIQUE (license_number),
    CONSTRAINT uq_drivers_email UNIQUE (email),
    CONSTRAINT chk_drivers_exp CHECK (experience_years >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. Table: vehicles
-- Logistics fleet vehicles with payload weight & volumetric capacities
-- ---------------------------------------------------------------------
CREATE TABLE vehicles (
    id VARCHAR(36) NOT NULL,
    license_plate VARCHAR(20) NOT NULL,
    model VARCHAR(100) NOT NULL,
    vehicle_type ENUM('MINI_VAN', 'LIGHT_TRUCK', 'HEAVY_TRUCK', 'CONTAINER') NOT NULL DEFAULT 'LIGHT_TRUCK',
    capacity_kg DECIMAL(10, 2) NOT NULL,
    capacity_m3 DECIMAL(10, 2) NULL,
    status ENUM('AVAILABLE', 'IN_USE', 'MAINTENANCE', 'RETIRED') NOT NULL DEFAULT 'AVAILABLE',
    last_maintenance_date DATE NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_vehicles PRIMARY KEY (id),
    CONSTRAINT uq_vehicles_plate UNIQUE (license_plate),
    CONSTRAINT chk_vehicles_cap_kg CHECK (capacity_kg > 0),
    CONSTRAINT chk_vehicles_cap_m3 CHECK (capacity_m3 IS NULL OR capacity_m3 > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. Table: routes
-- Predefined transportation paths, calculated distances, and transit times
-- ---------------------------------------------------------------------
CREATE TABLE routes (
    id VARCHAR(36) NOT NULL,
    name VARCHAR(100) NOT NULL,
    start_location VARCHAR(255) NOT NULL,
    end_location VARCHAR(255) NOT NULL,
    estimated_distance_km DECIMAL(10, 2) NOT NULL,
    estimated_time_minutes INT NOT NULL,
    toll_charges DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_routes PRIMARY KEY (id),
    CONSTRAINT chk_routes_distance CHECK (estimated_distance_km > 0),
    CONSTRAINT chk_routes_time CHECK (estimated_time_minutes > 0),
    CONSTRAINT chk_routes_toll CHECK (toll_charges >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. Table: shipments
-- Central entity managing parcel bookings, cargo manifests, and resource allocation
-- ---------------------------------------------------------------------
CREATE TABLE shipments (
    id VARCHAR(36) NOT NULL,
    tracking_number VARCHAR(50) NOT NULL,
    customer_id VARCHAR(36) NOT NULL,
    origin_address TEXT NOT NULL,
    destination_address TEXT NOT NULL,
    scheduled_pickup DATETIME NULL,
    scheduled_delivery DATETIME NULL,
    actual_delivery DATETIME NULL,
    status ENUM('PENDING', 'BOOKED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
    weight DECIMAL(10, 3) NOT NULL,
    volume DECIMAL(10, 3) NULL,
    cargo_type VARCHAR(100) NOT NULL DEFAULT 'General Goods',
    route_id VARCHAR(36) NULL,
    driver_id VARCHAR(36) NULL,
    vehicle_id VARCHAR(36) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_shipments PRIMARY KEY (id),
    CONSTRAINT uq_shipments_tracking UNIQUE (tracking_number),
    CONSTRAINT chk_shipments_weight CHECK (weight > 0),
    CONSTRAINT fk_shipments_customer FOREIGN KEY (customer_id) 
        REFERENCES customers(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_shipments_route FOREIGN KEY (route_id) 
        REFERENCES routes(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_shipments_driver FOREIGN KEY (driver_id) 
        REFERENCES drivers(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_shipments_vehicle FOREIGN KEY (vehicle_id) 
        REFERENCES vehicles(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. Table: driver_assignments
-- Preserves complete dispatch scheduling history between drivers, vehicles, and routes.
-- Enforces concurrency restrictions preventing double-booking active operators.
-- ---------------------------------------------------------------------
CREATE TABLE driver_assignments (
    id VARCHAR(36) NOT NULL,
    driver_id VARCHAR(36) NOT NULL,
    vehicle_id VARCHAR(36) NOT NULL,
    route_id VARCHAR(36) NULL,
    assignment_date DATE NOT NULL,
    shift_start DATETIME NULL,
    shift_end DATETIME NULL,
    status ENUM('SCHEDULED', 'ONGOING', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'SCHEDULED',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_driver_assignments PRIMARY KEY (id),
    CONSTRAINT fk_da_driver FOREIGN KEY (driver_id) 
        REFERENCES drivers(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_da_vehicle FOREIGN KEY (vehicle_id) 
        REFERENCES vehicles(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_da_route FOREIGN KEY (route_id) 
        REFERENCES routes(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. Table: tracking_events
-- Immutable timeline audit history for every shipment status milestone
-- ---------------------------------------------------------------------
CREATE TABLE tracking_events (
    id VARCHAR(36) NOT NULL,
    shipment_id VARCHAR(36) NOT NULL,
    event_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    location VARCHAR(255) NOT NULL,
    status VARCHAR(100) NOT NULL,
    notes TEXT NULL,
    created_by VARCHAR(50) NOT NULL DEFAULT 'SYSTEM',
    CONSTRAINT pk_tracking_events PRIMARY KEY (id),
    CONSTRAINT fk_te_shipment FOREIGN KEY (shipment_id) 
        REFERENCES shipments(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 9. Table: invoices
-- Financial billing records with base freight, 18% GST tax, and payment status
-- ---------------------------------------------------------------------
CREATE TABLE invoices (
    id VARCHAR(36) NOT NULL,
    invoice_number VARCHAR(100) NOT NULL,
    shipment_id VARCHAR(36) NOT NULL,
    customer_id VARCHAR(36) NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(12, 2) GENERATED ALWAYS AS (amount + tax_amount) STORED,
    currency CHAR(3) NOT NULL DEFAULT 'INR',
    billing_date DATE NOT NULL,
    due_date DATE NULL,
    status ENUM('UNPAID', 'PARTIAL', 'PAID', 'OVERDUE', 'CANCELLED') NOT NULL DEFAULT 'UNPAID',
    payment_method ENUM('NEFT', 'UPI', 'CREDIT_CARD', 'CASH', 'CHEQUE') NULL,
    paid_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_invoices PRIMARY KEY (id),
    CONSTRAINT uq_invoices_number UNIQUE (invoice_number),
    CONSTRAINT chk_invoices_amount CHECK (amount >= 0),
    CONSTRAINT chk_invoices_tax CHECK (tax_amount >= 0),
    CONSTRAINT fk_invoices_shipment FOREIGN KEY (shipment_id) 
        REFERENCES shipments(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_invoices_customer FOREIGN KEY (customer_id) 
        REFERENCES customers(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 10. Table: inventory
-- Warehouse packaging materials, pallets, security tags, and stock thresholds
-- ---------------------------------------------------------------------
CREATE TABLE inventory (
    id VARCHAR(36) NOT NULL,
    item_code VARCHAR(50) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    description TEXT NULL,
    category VARCHAR(100) NOT NULL DEFAULT 'Packaging Material',
    quantity INT NOT NULL DEFAULT 0,
    unit_of_measure VARCHAR(20) NOT NULL DEFAULT 'Units',
    reorder_level INT NOT NULL DEFAULT 20,
    unit_cost DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    location VARCHAR(100) NOT NULL DEFAULT 'Warehouse Central - Chennai',
    last_updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_inventory PRIMARY KEY (id),
    CONSTRAINT uq_inventory_code UNIQUE (item_code),
    CONSTRAINT chk_inventory_qty CHECK (quantity >= 0),
    CONSTRAINT chk_inventory_reorder CHECK (reorder_level >= 0),
    CONSTRAINT chk_inventory_cost CHECK (unit_cost >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 11. Table: partner_integrations
-- 3PL logistics dispatch APIs, Fastag toll bridges, and webhook configurations
-- ---------------------------------------------------------------------
CREATE TABLE partner_integrations (
    id VARCHAR(36) NOT NULL,
    partner_name VARCHAR(100) NOT NULL,
    integration_type ENUM('TRACKING_API', 'BILLING_GATEWAY', '3PL_DISPATCH', 'SMS_NOTIFICATION') NOT NULL,
    api_endpoint VARCHAR(500) NULL,
    auth_token VARCHAR(255) NULL,
    status ENUM('ACTIVE', 'INACTIVE', 'ERROR') NOT NULL DEFAULT 'ACTIVE',
    last_sync DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_partner_integrations PRIMARY KEY (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 12. Table: analytics_reports
-- Precomputed analytics snapshots and audit payloads stored in JSON format
-- ---------------------------------------------------------------------
CREATE TABLE analytics_reports (
    id VARCHAR(36) NOT NULL,
    report_type VARCHAR(100) NOT NULL,
    generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data JSON NOT NULL,
    related_shipment_id VARCHAR(36) NULL,
    related_driver_id VARCHAR(36) NULL,
    related_vehicle_id VARCHAR(36) NULL,
    related_event_id VARCHAR(36) NULL,
    CONSTRAINT pk_analytics_reports PRIMARY KEY (id),
    CONSTRAINT fk_ar_shipment FOREIGN KEY (related_shipment_id) 
        REFERENCES shipments(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_ar_driver FOREIGN KEY (related_driver_id) 
        REFERENCES drivers(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_ar_vehicle FOREIGN KEY (related_vehicle_id) 
        REFERENCES vehicles(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_ar_event FOREIGN KEY (related_event_id) 
        REFERENCES tracking_events(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;
