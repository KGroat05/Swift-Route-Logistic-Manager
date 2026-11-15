-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Analytical SQL Queries: 07_analytical_queries.sql
-- Demonstrates: Aggregates, Joins, Subqueries, GROUP BY, HAVING, Window Functions
-- Engine: MySQL 8.4 LTS
-- =====================================================================

USE swiftroute;

-- ---------------------------------------------------------------------
-- QUERY 1: Aggregates, GROUP BY, and HAVING
-- Identifies high-value corporate clients with >= 1 shipment and total billing > ₹20,000
-- ---------------------------------------------------------------------
SELECT 
    c.id AS customer_id,
    c.name AS customer_company,
    c.city,
    COUNT(s.id) AS total_shipments_placed,
    ROUND(SUM(s.weight), 2) AS total_cargo_weight_kg,
    ROUND(SUM(inv.total_amount), 2) AS total_billed_inr,
    ROUND(AVG(inv.total_amount), 2) AS avg_shipment_value_inr
FROM customers c
INNER JOIN shipments s ON c.id = s.customer_id
LEFT JOIN invoices inv ON s.id = inv.shipment_id
GROUP BY c.id, c.name, c.city
HAVING total_billed_inr > 20000.00
ORDER BY total_billed_inr DESC;

-- ---------------------------------------------------------------------
-- QUERY 2: Multi-Table 5-Way JOIN with Utilization Calculation
-- Active manifest joining shipments, customers, routes, drivers, and vehicles
-- ---------------------------------------------------------------------
SELECT 
    s.tracking_number,
    c.name AS sender,
    r.name AS route,
    d.name AS driver,
    d.phone AS driver_phone,
    v.license_plate AS vehicle_plate,
    v.model AS vehicle_model,
    s.weight AS cargo_weight_kg,
    v.capacity_kg AS vehicle_max_capacity_kg,
    ROUND((s.weight / v.capacity_kg) * 100, 2) AS capacity_utilization_pct,
    s.status AS shipment_status
FROM shipments s
INNER JOIN customers c ON s.customer_id = c.id
INNER JOIN routes r ON s.route_id = r.id
LEFT JOIN drivers d ON s.driver_id = d.id
LEFT JOIN vehicles v ON s.vehicle_id = v.id
WHERE s.status IN ('BOOKED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY')
ORDER BY capacity_utilization_pct DESC;

-- ---------------------------------------------------------------------
-- QUERY 3: Scalar & Correlated Subqueries
-- Shipments exceeding the fleet-wide average payload weight
-- ---------------------------------------------------------------------
SELECT 
    s.id,
    s.tracking_number,
    s.cargo_type,
    s.weight,
    (SELECT ROUND(AVG(weight), 2) FROM shipments) AS fleet_avg_weight_kg,
    ROUND(s.weight - (SELECT AVG(weight) FROM shipments), 2) AS diff_from_average,
    c.name AS customer_name
FROM shipments s
INNER JOIN customers c ON s.customer_id = c.id
WHERE s.weight > (
    SELECT AVG(inner_s.weight) 
    FROM shipments inner_s
)
ORDER BY s.weight DESC;

-- ---------------------------------------------------------------------
-- QUERY 4: Subquery with EXISTS
-- Finds all routes that currently have at least one DELIVERED consignment
-- ---------------------------------------------------------------------
SELECT 
    r.id, 
    r.name, 
    r.start_location, 
    r.end_location, 
    r.estimated_distance_km
FROM routes r
WHERE EXISTS (
    SELECT 1 
    FROM shipments s 
    WHERE s.route_id = r.id 
      AND s.status = 'DELIVERED'
);

-- ---------------------------------------------------------------------
-- QUERY 5: Subquery with NOT IN
-- Finds vehicles that have never been scheduled or dispatched
-- ---------------------------------------------------------------------
SELECT 
    v.id, 
    v.license_plate, 
    v.model, 
    v.capacity_kg, 
    v.status
FROM vehicles v
WHERE v.id NOT IN (
    SELECT DISTINCT vehicle_id 
    FROM driver_assignments 
    WHERE vehicle_id IS NOT NULL
);

-- ---------------------------------------------------------------------
-- QUERY 6: Set Operations (UNION)
-- Unified directory of all system logistical parties (Customers & Drivers)
-- ---------------------------------------------------------------------
SELECT 
    'CUSTOMER' AS party_type,
    name AS party_name,
    contact_phone AS phone,
    contact_email AS email,
    city AS location
FROM customers
UNION
SELECT 
    'DRIVER' AS party_type,
    name AS party_name,
    phone,
    email,
    'Field Operations' AS location
FROM drivers
ORDER BY party_name ASC;

-- ---------------------------------------------------------------------
-- QUERY 7: Window Functions (ROW_NUMBER, DENSE_RANK, SUM OVER)
-- Ranks shipments by weight per route and calculates running cumulative load
-- ---------------------------------------------------------------------
SELECT 
    s.id,
    s.tracking_number,
    r.name AS route_name,
    s.weight,
    ROW_NUMBER() OVER (PARTITION BY s.route_id ORDER BY s.weight DESC) AS route_rank,
    DENSE_RANK() OVER (ORDER BY s.weight DESC) AS global_heavy_rank,
    SUM(s.weight) OVER (PARTITION BY s.route_id ORDER BY s.created_at) AS cumulative_route_load_kg
FROM shipments s
LEFT JOIN routes r ON s.route_id = r.id
ORDER BY r.name, route_rank;

-- ---------------------------------------------------------------------
-- QUERY 8: Financial Aging Analysis
-- Identifies overdue accounts receivable and calculates days overdue
-- ---------------------------------------------------------------------
SELECT 
    inv.invoice_number,
    c.name AS customer_name,
    inv.total_amount AS invoice_amount_inr,
    inv.billing_date,
    inv.due_date,
    inv.status,
    DATEDIFF(CURDATE(), inv.due_date) AS days_overdue
FROM invoices inv
INNER JOIN customers c ON inv.customer_id = c.id
WHERE inv.status = 'OVERDUE' OR (inv.status = 'UNPAID' AND inv.due_date < CURDATE())
ORDER BY days_overdue DESC;
