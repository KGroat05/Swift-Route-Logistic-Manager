-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Performance Indexes: 02_indexes.sql
-- Engine: MySQL 8.4 LTS
-- =====================================================================

USE swiftroute;

-- 1. Users Indexes
CREATE INDEX idx_users_role ON users (role, is_active);

-- 2. Customers Indexes (Search by company name and geographic city)
CREATE INDEX idx_customers_name ON customers (name);
CREATE INDEX idx_customers_city_state ON customers (city, state);

-- 3. Drivers Indexes (Status filtering and experience queries)
CREATE INDEX idx_drivers_status_exp ON drivers (status, experience_years DESC);
CREATE INDEX idx_drivers_hired ON drivers (hired_date);

-- 4. Vehicles Indexes (Fleet dispatch search & capacity queries)
CREATE INDEX idx_vehicles_status_cap ON vehicles (status, capacity_kg DESC);
CREATE INDEX idx_vehicles_type ON vehicles (vehicle_type, status);

-- 5. Routes Indexes (Search corridors by starting and terminating terminals)
CREATE INDEX idx_routes_start_end ON routes (start_location(50), end_location(50));
CREATE INDEX idx_routes_distance ON routes (estimated_distance_km);

-- 6. Shipments Indexes (Composite index for status and scheduled dates)
CREATE INDEX idx_shipments_status_pickup ON shipments (status, scheduled_pickup);
CREATE INDEX idx_shipments_cust_created ON shipments (customer_id, created_at DESC);
CREATE INDEX idx_shipments_driver_active ON shipments (driver_id, status);
CREATE INDEX idx_shipments_vehicle_active ON shipments (vehicle_id, status);
CREATE INDEX idx_shipments_route ON shipments (route_id);

-- 7. Driver Assignments Indexes (Quick lookup for concurrent schedule overlap)
CREATE INDEX idx_da_driver_schedule ON driver_assignments (driver_id, assignment_date, status);
CREATE INDEX idx_da_vehicle_schedule ON driver_assignments (vehicle_id, assignment_date, status);

-- 8. Tracking Events Indexes (Chronological timeline lookup per shipment)
CREATE INDEX idx_te_shipment_time ON tracking_events (shipment_id, event_time ASC);

-- 9. Invoices Indexes (Financial aging, overdue tracking, and customer accounts)
CREATE INDEX idx_invoices_status_due ON invoices (status, due_date);
CREATE INDEX idx_invoices_customer_date ON invoices (customer_id, billing_date DESC);
CREATE INDEX idx_invoices_shipment ON invoices (shipment_id);

-- 10. Inventory Indexes (Warehouse inventory category filtering and stock alerts)
CREATE INDEX idx_inventory_category_qty ON inventory (category, quantity);
CREATE INDEX idx_inventory_reorder_scan ON inventory (quantity, reorder_level);

-- 11. Analytics Reports Indexes
CREATE INDEX idx_ar_report_type_time ON analytics_reports (report_type, generated_at DESC);
