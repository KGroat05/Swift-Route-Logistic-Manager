-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Performance Indexes: 06_indexes.sql
-- Engine: MySQL 8.4 LTS
-- =====================================================================

USE swiftroute;

-- Index for searching shipments by status and scheduled date range
CREATE INDEX idx_shipments_status_pickup ON shipments (status, scheduled_pickup);

-- Index for querying customer shipments sorted by date
CREATE INDEX idx_shipments_cust_date ON shipments (customer_id, created_at DESC);

-- Composite index for route search
CREATE INDEX idx_routes_cities ON routes (start_location(50), end_location(50));

-- Index for driver availability and experience queries
CREATE INDEX idx_drivers_status_exp ON drivers (status, experience_years DESC);

-- Index for vehicle status and payload lookup
CREATE INDEX idx_vehicles_status_cap ON vehicles (status, capacity_kg DESC);

-- Index for billing status and due date (used for finding overdue invoices)
CREATE INDEX idx_billing_status_due ON billing (status, due_date);

-- Index for tracking timeline sorting
CREATE INDEX idx_te_shipment_time ON tracking_events (shipment_id, event_time ASC);

-- Index for inventory category and quantity (reorder queries)
CREATE INDEX idx_inventory_cat_qty ON inventory (category, quantity);
