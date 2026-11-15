-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Relational Views: 03_views.sql
-- Engine: MySQL 8.4 LTS
-- =====================================================================

USE swiftroute;

-- ---------------------------------------------------------------------
-- 1. View: vw_shipment_details (Comprehensive Multi-Table Join)
-- Joins: shipments, customers, routes, drivers, vehicles, billing
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_shipment_details AS
SELECT 
    s.id AS shipment_id,
    s.tracking_number,
    s.status AS shipment_status,
    s.cargo_type,
    s.weight AS weight_kg,
    s.volume AS volume_m3,
    s.scheduled_pickup,
    s.scheduled_delivery,
    s.actual_delivery,
    s.created_at AS booking_date,
    
    -- Customer info
    c.id AS customer_id,
    c.name AS customer_name,
    c.contact_name AS customer_contact,
    c.contact_phone AS customer_phone,
    c.contact_email AS customer_email,
    c.city AS customer_city,
    
    -- Route info
    r.id AS route_id,
    r.name AS route_name,
    r.start_location,
    r.end_location,
    r.estimated_distance_km,
    r.estimated_time_minutes,
    
    -- Driver info
    d.id AS driver_id,
    d.name AS driver_name,
    d.phone AS driver_phone,
    d.license_number AS driver_license,
    
    -- Vehicle info
    v.id AS vehicle_id,
    v.license_plate AS vehicle_plate,
    v.model AS vehicle_model,
    v.vehicle_type,
    v.capacity_kg AS vehicle_capacity_kg,
    ROUND((s.weight / v.capacity_kg) * 100, 2) AS vehicle_payload_utilization_pct,
    
    -- Billing info
    b.id AS billing_id,
    b.invoice_number,
    b.amount AS billing_base_amount,
    b.tax_amount AS billing_tax,
    b.total_amount AS invoice_total,
    b.status AS payment_status
FROM shipments s
INNER JOIN customers c ON s.customer_id = c.id
LEFT JOIN routes r ON s.route_id = r.id
LEFT JOIN drivers d ON s.driver_id = d.id
LEFT JOIN vehicles v ON s.vehicle_id = v.id
LEFT JOIN billing b ON s.id = b.shipment_id;

-- ---------------------------------------------------------------------
-- 2. View: vw_driver_performance (Driver Performance & Utilization)
-- Demonstrates Aggregate Functions with GROUP BY, CASE Expressions
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_driver_performance AS
SELECT 
    d.id AS driver_id,
    d.name AS driver_name,
    d.license_number,
    d.phone,
    d.status AS driver_status,
    d.experience_years,
    COUNT(s.id) AS total_assigned_shipments,
    SUM(CASE WHEN s.status = 'DELIVERED' THEN 1 ELSE 0 END) AS delivered_shipments,
    SUM(CASE WHEN s.status IN ('IN_TRANSIT', 'OUT_FOR_DELIVERY') THEN 1 ELSE 0 END) AS active_shipments,
    SUM(CASE WHEN s.status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_shipments,
    COALESCE(SUM(CASE WHEN s.status = 'DELIVERED' THEN r.estimated_distance_km ELSE 0 END), 0.00) AS total_distance_km_delivered,
    COALESCE(ROUND(AVG(CASE WHEN s.status = 'DELIVERED' THEN s.weight ELSE NULL END), 2), 0.00) AS avg_payload_kg,
    ROUND(
        CASE 
            WHEN COUNT(s.id) = 0 THEN 0.00
            ELSE (SUM(CASE WHEN s.status = 'DELIVERED' THEN 1 ELSE 0 END) / COUNT(s.id)) * 100
        END, 2
    ) AS delivery_success_rate_pct
FROM drivers d
LEFT JOIN shipments s ON d.id = s.driver_id
LEFT JOIN routes r ON s.route_id = r.id
GROUP BY d.id, d.name, d.license_number, d.phone, d.status, d.experience_years;

-- ---------------------------------------------------------------------
-- 3. View: vw_route_analytics (Route Efficiency & Revenue)
-- Demonstrates Aggregate Functions & Multi-Table Relationships
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_route_analytics AS
SELECT 
    r.id AS route_id,
    r.name AS route_name,
    r.start_location,
    r.end_location,
    r.estimated_distance_km,
    r.estimated_time_minutes,
    COUNT(s.id) AS total_shipments_routed,
    COALESCE(SUM(s.weight), 0.00) AS total_cargo_weight_kg,
    COALESCE(SUM(b.total_amount), 0.00) AS total_revenue_generated,
    ROUND(
        CASE 
            WHEN r.estimated_distance_km > 0 AND SUM(b.total_amount) IS NOT NULL 
            THEN SUM(b.total_amount) / (COUNT(s.id) * r.estimated_distance_km)
            ELSE 0.00
        END, 2
    ) AS revenue_per_km_inr
FROM routes r
LEFT JOIN shipments s ON r.id = s.route_id
LEFT JOIN billing b ON s.id = b.shipment_id
GROUP BY r.id, r.name, r.start_location, r.end_location, r.estimated_distance_km, r.estimated_time_minutes;

-- ---------------------------------------------------------------------
-- 4. View: vw_financial_summary (Accounts Receivable & Billing Status)
-- Demonstrates Conditional Aggregations & Percentage Metrics
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_financial_summary AS
SELECT 
    COUNT(b.id) AS total_invoices,
    COALESCE(SUM(b.total_amount), 0.00) AS gross_billed_amount,
    COALESCE(SUM(CASE WHEN b.status = 'PAID' THEN b.total_amount ELSE 0.00 END), 0.00) AS collected_revenue,
    COALESCE(SUM(CASE WHEN b.status = 'UNPAID' THEN b.total_amount ELSE 0.00 END), 0.00) AS pending_receivables,
    COALESCE(SUM(CASE WHEN b.status = 'OVERDUE' THEN b.total_amount ELSE 0.00 END), 0.00) AS overdue_receivables,
    COALESCE(SUM(b.tax_amount), 0.00) AS total_gst_tax_collected,
    ROUND(
        CASE 
            WHEN SUM(b.total_amount) > 0 
            THEN (SUM(CASE WHEN b.status = 'PAID' THEN b.total_amount ELSE 0.00 END) / SUM(b.total_amount)) * 100
            ELSE 0.00
        END, 2
    ) AS collection_efficiency_pct
FROM billing b;

-- ---------------------------------------------------------------------
-- 5. View: vw_low_stock_inventory (Inventory Depletion Alerts)
-- Filters items requiring immediate replenishment
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_low_stock_inventory AS
SELECT 
    i.id,
    i.item_code,
    i.item_name,
    i.category,
    i.quantity AS current_stock,
    i.reorder_level,
    (i.reorder_level - i.quantity) AS deficit_quantity,
    i.unit_cost,
    ROUND((i.reorder_level - i.quantity) * i.unit_cost, 2) AS estimated_restock_cost,
    i.location,
    i.last_updated
FROM inventory i
WHERE i.quantity <= i.reorder_level;
