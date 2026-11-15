-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Relational Views for Reporting: 04_views.sql
-- Engine: MySQL 8.4 LTS
-- =====================================================================

USE swiftroute;

-- ---------------------------------------------------------------------
-- 1. View: vw_shipment_details (Comprehensive Multi-Table Join)
-- Joins: shipments, customers, routes, drivers, vehicles, invoices
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_shipment_details AS
SELECT 
    s.id AS shipment_id,
    s.tracking_number,
    s.status AS shipment_status,
    s.cargo_type,
    s.weight AS weight_kg,
    s.volume AS volume_m3,
    s.origin_address,
    s.destination_address,
    s.scheduled_pickup,
    s.scheduled_delivery,
    s.actual_delivery,
    s.created_at AS booking_date,
    
    -- Customer information
    c.id AS customer_id,
    c.name AS customer_name,
    c.contact_name AS customer_contact,
    c.contact_phone AS customer_phone,
    c.contact_email AS customer_email,
    c.city AS customer_city,
    
    -- Route information
    r.id AS route_id,
    r.name AS route_name,
    r.start_location,
    r.end_location,
    r.estimated_distance_km,
    r.estimated_time_minutes,
    
    -- Driver information
    d.id AS driver_id,
    d.name AS driver_name,
    d.phone AS driver_phone,
    d.license_number AS driver_license,
    d.status AS driver_status,
    
    -- Vehicle information
    v.id AS vehicle_id,
    v.license_plate AS vehicle_plate,
    v.model AS vehicle_model,
    v.vehicle_type,
    v.capacity_kg AS vehicle_capacity_kg,
    ROUND((s.weight / v.capacity_kg) * 100, 2) AS vehicle_payload_utilization_pct,
    
    -- Invoice information
    inv.id AS invoice_id,
    inv.invoice_number,
    inv.amount AS base_freight_amount,
    inv.tax_amount AS gst_tax_amount,
    inv.total_amount AS invoice_total,
    inv.status AS payment_status,
    inv.payment_method,
    inv.paid_at
FROM shipments s
INNER JOIN customers c ON s.customer_id = c.id
LEFT JOIN routes r ON s.route_id = r.id
LEFT JOIN drivers d ON s.driver_id = d.id
LEFT JOIN vehicles v ON s.vehicle_id = v.id
LEFT JOIN invoices inv ON s.id = inv.shipment_id;

-- ---------------------------------------------------------------------
-- 2. View: vw_dashboard_kpis (Live Aggregated Logistics Metrics)
-- Consolidates real-time operational metrics for dashboard visualization
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_dashboard_kpis AS
SELECT 
    (SELECT COUNT(*) FROM customers) AS total_customers,
    (SELECT COUNT(*) FROM shipments) AS total_shipments,
    (SELECT COUNT(*) FROM shipments WHERE status IN ('BOOKED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY')) AS active_shipments,
    (SELECT COUNT(*) FROM shipments WHERE status = 'DELIVERED') AS delivered_shipments,
    (SELECT COUNT(*) FROM shipments WHERE status = 'CANCELLED') AS cancelled_shipments,
    (SELECT COUNT(*) FROM drivers WHERE status IN ('ACTIVE', 'ON_DUTY')) AS active_drivers,
    (SELECT COUNT(*) FROM vehicles WHERE status = 'AVAILABLE') AS available_vehicles,
    (SELECT COALESCE(SUM(total_amount), 0.00) FROM invoices WHERE status = 'PAID') AS collected_revenue_inr,
    (SELECT COALESCE(SUM(total_amount), 0.00) FROM invoices WHERE status IN ('UNPAID', 'OVERDUE')) AS pending_receivables_inr,
    (SELECT COUNT(*) FROM invoices WHERE status = 'OVERDUE') AS overdue_invoices_count,
    (SELECT COUNT(*) FROM inventory WHERE quantity <= reorder_level) AS low_stock_items_count;

-- ---------------------------------------------------------------------
-- 3. View: vw_driver_performance (Driver Performance Leaderboard)
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
    SUM(CASE WHEN s.status IN ('BOOKED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY') THEN 1 ELSE 0 END) AS active_shipments,
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
-- 4. View: vw_route_analytics (Route Efficiency & Profitability)
-- Aggregates freight traffic volume, cumulative weight, and revenue
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
    COALESCE(SUM(inv.total_amount), 0.00) AS total_revenue_generated,
    ROUND(
        CASE 
            WHEN r.estimated_distance_km > 0 AND SUM(inv.total_amount) IS NOT NULL AND COUNT(s.id) > 0
            THEN SUM(inv.total_amount) / (COUNT(s.id) * r.estimated_distance_km)
            ELSE 0.00
        END, 2
    ) AS revenue_per_km_inr
FROM routes r
LEFT JOIN shipments s ON r.id = s.route_id
LEFT JOIN invoices inv ON s.id = inv.shipment_id
GROUP BY r.id, r.name, r.start_location, r.end_location, r.estimated_distance_km, r.estimated_time_minutes;

-- ---------------------------------------------------------------------
-- 5. View: vw_invoice_aging_summary (Accounts Receivable Summary)
-- Financial report categorizing billed revenues and collection efficiency
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_invoice_aging_summary AS
SELECT 
    COUNT(inv.id) AS total_invoices,
    COALESCE(SUM(inv.total_amount), 0.00) AS gross_billed_amount,
    COALESCE(SUM(CASE WHEN inv.status = 'PAID' THEN inv.total_amount ELSE 0.00 END), 0.00) AS collected_revenue,
    COALESCE(SUM(CASE WHEN inv.status = 'UNPAID' THEN inv.total_amount ELSE 0.00 END), 0.00) AS pending_receivables,
    COALESCE(SUM(CASE WHEN inv.status = 'OVERDUE' THEN inv.total_amount ELSE 0.00 END), 0.00) AS overdue_receivables,
    COALESCE(SUM(inv.tax_amount), 0.00) AS total_gst_collected,
    ROUND(
        CASE 
            WHEN SUM(inv.total_amount) > 0 
            THEN (SUM(CASE WHEN inv.status = 'PAID' THEN inv.total_amount ELSE 0.00 END) / SUM(inv.total_amount)) * 100
            ELSE 0.00
        END, 2
    ) AS collection_efficiency_pct
FROM invoices inv;

-- Backward compatibility alias
CREATE OR REPLACE VIEW vw_financial_summary AS SELECT * FROM vw_invoice_aging_summary;

-- ---------------------------------------------------------------------
-- 6. View: vw_low_stock_inventory (Warehouse Depletion Alerts)
-- Filters items at or below minimum threshold for automatic replenishment
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
