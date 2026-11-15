-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Advanced Demonstration Queries: 07_advanced_queries.sql
-- Engine: MySQL 8.4 LTS
-- =====================================================================

USE swiftroute;

-- ---------------------------------------------------------------------
-- QUERY 1: Aggregates, GROUP BY, and HAVING
-- Find customers with more than 1 shipment and total billing exceeding ₹20,000
-- ---------------------------------------------------------------------
SELECT 
    c.id AS customer_id,
    c.name AS customer_company,
    c.city,
    COUNT(s.id) AS total_shipments_placed,
    ROUND(SUM(s.weight), 2) AS total_weight_kg,
    ROUND(SUM(b.total_amount), 2) AS total_billed_inr,
    ROUND(AVG(b.total_amount), 2) AS avg_shipment_value_inr
FROM customers c
INNER JOIN shipments s ON c.id = s.customer_id
LEFT JOIN billing b ON s.id = b.shipment_id
GROUP BY c.id, c.name, c.city
HAVING COUNT(s.id) >= 1 AND total_billed_inr > 20000.00
ORDER BY total_billed_inr DESC;

-- ---------------------------------------------------------------------
-- QUERY 2: Multi-Table Joins (INNER, LEFT) with Conditional Logic
-- Active Manifest Report showing driver, vehicle, and cargo load percent
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
-- QUERY 3: Subqueries (Correlated Subquery & Scalar Subquery)
-- Find shipments whose weight is greater than the average weight across all shipments
-- ---------------------------------------------------------------------
SELECT 
    s.id,
    s.tracking_number,
    s.cargo_type,
    s.weight,
    (SELECT ROUND(AVG(weight), 2) FROM shipments) AS overall_avg_weight,
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
-- Find all routes that currently have at least one DELIVERED shipment
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
-- Find vehicles that have NEVER had any maintenance or never been assigned
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
-- Unified directory of all system contact parties (Customers and Drivers)
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
    'Field Logistics' AS location
FROM drivers
ORDER BY party_name ASC;

-- ---------------------------------------------------------------------
-- QUERY 7: Window Functions (ROW_NUMBER, DENSE_RANK, SUM OVER)
-- Rank shipments by weight partitioned by route, and running cumulative weight
-- ---------------------------------------------------------------------
SELECT 
    s.id,
    s.tracking_number,
    r.name AS route_name,
    s.weight,
    ROW_NUMBER() OVER (PARTITION BY s.route_id ORDER BY s.weight DESC) AS route_weight_row_num,
    DENSE_RANK() OVER (ORDER BY s.weight DESC) AS global_weight_rank,
    SUM(s.weight) OVER (PARTITION BY s.route_id ORDER BY s.created_at) AS cumulative_route_cargo_kg
FROM shipments s
LEFT JOIN routes r ON s.route_id = r.id
ORDER BY r.name, route_weight_row_num;

-- ---------------------------------------------------------------------
-- QUERY 8: Financial Aging Analysis using Date Functions
-- Identifies overdue invoices and days outstanding
-- ---------------------------------------------------------------------
SELECT 
    b.invoice_number,
    c.name AS customer_name,
    b.total_amount AS invoice_amount_inr,
    b.billing_date,
    b.due_date,
    b.status,
    DATEDIFF(CURDATE(), b.due_date) AS days_overdue
FROM billing b
INNER JOIN customers c ON b.customer_id = c.id
WHERE b.status = 'OVERDUE' OR (b.status = 'UNPAID' AND b.due_date < CURDATE())
ORDER BY days_overdue DESC;
