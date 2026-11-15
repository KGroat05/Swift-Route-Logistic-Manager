-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Stored Procedures & Functions: 05_procedures.sql
-- Engine: MySQL 8.4 LTS
-- =====================================================================

USE swiftroute;

DROP FUNCTION IF EXISTS fn_calculate_freight_charge;
DROP PROCEDURE IF EXISTS sp_lookup_shipment_details;
DROP PROCEDURE IF EXISTS sp_generate_operational_report;
DROP PROCEDURE IF EXISTS sp_book_shipment_with_assignment;
DROP PROCEDURE IF EXISTS sp_update_shipment_status;
DROP PROCEDURE IF EXISTS sp_calculate_driver_payout;
DROP PROCEDURE IF EXISTS sp_audit_inventory_restock;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. Stored Function: fn_calculate_freight_charge
-- Computes logistics freight cost based on cargo weight and route distance
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_calculate_freight_charge(
    p_weight_kg DECIMAL(10,3),
    p_distance_km DECIMAL(10,2)
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_base_rate DECIMAL(10,2) DEFAULT 500.00;
    DECLARE v_weight_cost DECIMAL(10,2);
    DECLARE v_distance_cost DECIMAL(10,2);
    DECLARE v_total DECIMAL(12,2);

    -- Slabs: 2.50 INR per kg, 6.00 INR per km
    SET v_weight_cost = p_weight_kg * 2.50;
    SET v_distance_cost = p_distance_km * 6.00;
    SET v_total = v_base_rate + v_weight_cost + v_distance_cost;
    
    RETURN ROUND(v_total, 2);
END$$

-- ---------------------------------------------------------------------
-- 2. Stored Procedure: sp_lookup_shipment_details
-- Comprehensive lookup returning shipment manifest and chronological timeline
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_lookup_shipment_details(
    IN p_tracking_or_id VARCHAR(50)
)
BEGIN
    -- Query 1: Full Manifest Record
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
        s.created_at,
        c.name AS customer_name,
        c.contact_phone AS customer_phone,
        r.name AS route_name,
        r.estimated_distance_km,
        d.name AS driver_name,
        d.phone AS driver_phone,
        v.license_plate AS vehicle_plate,
        v.model AS vehicle_model,
        inv.invoice_number,
        inv.total_amount,
        inv.status AS invoice_status
    FROM shipments s
    INNER JOIN customers c ON s.customer_id = c.id
    LEFT JOIN routes r ON s.route_id = r.id
    LEFT JOIN drivers d ON s.driver_id = d.id
    LEFT JOIN vehicles v ON s.vehicle_id = v.id
    LEFT JOIN invoices inv ON s.id = inv.shipment_id
    WHERE s.tracking_number = p_tracking_or_id OR s.id = p_tracking_or_id;

    -- Query 2: Associated Chronological Timeline
    SELECT 
        te.id AS event_id,
        te.event_time,
        te.location,
        te.status AS milestone_status,
        te.notes,
        te.created_by
    FROM tracking_events te
    INNER JOIN shipments s ON te.shipment_id = s.id
    WHERE s.tracking_number = p_tracking_or_id OR s.id = p_tracking_or_id
    ORDER BY te.event_time ASC;
END$$

-- ---------------------------------------------------------------------
-- 3. Stored Procedure: sp_generate_operational_report
-- Summarizes logistics throughput and revenues within a given date window
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_generate_operational_report(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        p_start_date AS report_start_date,
        p_end_date AS report_end_date,
        COUNT(s.id) AS total_booked_shipments,
        COALESCE(SUM(s.weight), 0.00) AS total_cargo_weight_kg,
        SUM(CASE WHEN s.status = 'DELIVERED' THEN 1 ELSE 0 END) AS delivered_count,
        SUM(CASE WHEN s.status IN ('BOOKED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY') THEN 1 ELSE 0 END) AS active_in_transit_count,
        SUM(CASE WHEN s.status = 'CANCELLED' THEN 1 ELSE 0 END) AS cancelled_count,
        COALESCE(SUM(inv.total_amount), 0.00) AS total_billed_inr,
        COALESCE(SUM(CASE WHEN inv.status = 'PAID' THEN inv.total_amount ELSE 0.00 END), 0.00) AS total_collected_revenue_inr,
        ROUND(
            CASE 
                WHEN COUNT(s.id) > 0 THEN (SUM(CASE WHEN s.status = 'DELIVERED' THEN 1 ELSE 0 END) / COUNT(s.id)) * 100
                ELSE 0.00 
            END, 2
        ) AS delivery_success_rate_pct
    FROM shipments s
    LEFT JOIN invoices inv ON s.id = inv.shipment_id
    WHERE DATE(s.created_at) BETWEEN p_start_date AND p_end_date;
END$$

-- ---------------------------------------------------------------------
-- 4. Stored Procedure: sp_book_shipment_with_assignment
-- Full Transaction with Capacity Validation, Pessimistic Row Lock, Savepoints
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_book_shipment_with_assignment(
    IN p_shipment_id VARCHAR(36),
    IN p_tracking_number VARCHAR(50),
    IN p_customer_id VARCHAR(36),
    IN p_origin TEXT,
    IN p_destination TEXT,
    IN p_weight DECIMAL(10,3),
    IN p_volume DECIMAL(10,3),
    IN p_cargo_type VARCHAR(100),
    IN p_route_id VARCHAR(36),
    IN p_driver_id VARCHAR(36),
    IN p_vehicle_id VARCHAR(36),
    IN p_billing_amount DECIMAL(12,2),
    IN p_payment_method VARCHAR(50),
    OUT p_status_code INT,
    OUT p_status_message VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_vehicle_capacity DECIMAL(10,2);
    DECLARE v_vehicle_status VARCHAR(50);
    DECLARE v_driver_status VARCHAR(50);
    DECLARE v_invoice_id VARCHAR(36);
    DECLARE v_invoice_num VARCHAR(100);
    DECLARE v_tax DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status_code = 500;
        SET p_status_message = 'Database error occurred during shipment booking. Entire transaction rolled back.';
    END;

    -- Step 1: Validate Customer
    IF NOT EXISTS (SELECT 1 FROM customers WHERE id = p_customer_id) THEN
        SET p_status_code = 404;
        SET p_status_message = 'Customer record not found.';
        LEAVE proc_label;
    END IF;

    -- Step 2: Validate Vehicle Capacity and Availability (if provided)
    IF p_vehicle_id IS NOT NULL THEN
        -- Acquire pessimistic row lock
        SELECT capacity_kg, status INTO v_vehicle_capacity, v_vehicle_status 
        FROM vehicles WHERE id = p_vehicle_id FOR UPDATE;

        IF v_vehicle_capacity IS NULL THEN
            SET p_status_code = 404;
            SET p_status_message = 'Vehicle not found.';
            LEAVE proc_label;
        END IF;

        IF v_vehicle_status <> 'AVAILABLE' THEN
            SET p_status_code = 409;
            SET p_status_message = CONCAT('Selected vehicle is not available (Current status: ', v_vehicle_status, ').');
            LEAVE proc_label;
        END IF;

        IF p_weight > v_vehicle_capacity THEN
            SET p_status_code = 422;
            SET p_status_message = CONCAT('Payload weight (', p_weight, ' kg) exceeds vehicle capacity (', v_vehicle_capacity, ' kg).');
            LEAVE proc_label;
        END IF;
    END IF;

    -- Step 3: Validate Driver Readiness (if provided)
    IF p_driver_id IS NOT NULL THEN
        -- Acquire pessimistic row lock
        SELECT status INTO v_driver_status FROM drivers WHERE id = p_driver_id FOR UPDATE;

        IF v_driver_status IS NULL THEN
            SET p_status_code = 404;
            SET p_status_message = 'Driver not found.';
            LEAVE proc_label;
        END IF;

        IF v_driver_status <> 'ACTIVE' THEN
            SET p_status_code = 409;
            SET p_status_message = CONCAT('Selected driver is not ready for dispatch (Current status: ', v_driver_status, ').');
            LEAVE proc_label;
        END IF;
    END IF;

    -- Step 4: Begin Transaction
    START TRANSACTION;
    SAVEPOINT sp_before_shipment_creation;

    -- Insert shipment
    INSERT INTO shipments (
        id, tracking_number, customer_id, origin_address, destination_address,
        scheduled_pickup, scheduled_delivery, status, weight, volume, cargo_type,
        route_id, driver_id, vehicle_id, created_at
    ) VALUES (
        p_shipment_id, p_tracking_number, p_customer_id, p_origin, p_destination,
        NOW(), DATE_ADD(NOW(), INTERVAL 24 HOUR),
        CASE WHEN p_vehicle_id IS NOT NULL AND p_driver_id IS NOT NULL THEN 'BOOKED' ELSE 'PENDING' END,
        p_weight, p_volume, p_cargo_type, p_route_id, p_driver_id, p_vehicle_id, NOW()
    );

    -- Generate Invoice if amount > 0
    IF p_billing_amount > 0 THEN
        SET v_invoice_id = UUID();
        SET v_invoice_num = CONCAT('INV-', DATE_FORMAT(NOW(), '%Y%m%d'), '-', SUBSTRING(p_shipment_id, 1, 6));
        SET v_tax = ROUND(p_billing_amount * 0.18, 2);

        INSERT INTO invoices (
            id, invoice_number, shipment_id, customer_id, amount, tax_amount,
            currency, billing_date, due_date, status, payment_method
        ) VALUES (
            v_invoice_id, v_invoice_num, p_shipment_id, p_customer_id, p_billing_amount, v_tax,
            'INR', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 15 DAY), 'UNPAID', p_payment_method
        );
    END IF;

    -- Update Vehicle & Driver Statuses if assigned
    IF p_vehicle_id IS NOT NULL THEN
        UPDATE vehicles SET status = 'IN_USE' WHERE id = p_vehicle_id;
    END IF;

    IF p_driver_id IS NOT NULL THEN
        UPDATE drivers SET status = 'ON_DUTY' WHERE id = p_driver_id;
    END IF;

    -- Schedule Driver Assignment
    IF p_driver_id IS NOT NULL AND p_vehicle_id IS NOT NULL THEN
        INSERT INTO driver_assignments (
            id, driver_id, vehicle_id, route_id, assignment_date, shift_start, status
        ) VALUES (
            UUID(), p_driver_id, p_vehicle_id, p_route_id, CURDATE(), NOW(), 'SCHEDULED'
        );
    END IF;

    COMMIT;
    SET p_status_code = 201;
    SET p_status_message = 'Shipment booked and resources successfully dispatched.';
END$$

-- ---------------------------------------------------------------------
-- 5. Stored Procedure: sp_update_shipment_status
-- Transitions shipment status, adds tracking event, and releases fleet
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_update_shipment_status(
    IN p_shipment_id VARCHAR(36),
    IN p_new_status VARCHAR(50),
    IN p_location VARCHAR(255),
    IN p_notes TEXT,
    IN p_updated_by VARCHAR(50),
    OUT p_rows_affected INT
)
BEGIN
    DECLARE v_prev_status VARCHAR(50);
    DECLARE v_vehicle_id VARCHAR(36);
    DECLARE v_driver_id VARCHAR(36);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_rows_affected = -1;
    END;

    START TRANSACTION;

    SELECT status, vehicle_id, driver_id INTO v_prev_status, v_vehicle_id, v_driver_id
    FROM shipments WHERE id = p_shipment_id FOR UPDATE;

    IF v_prev_status IS NOT NULL THEN
        -- Update shipment status
        UPDATE shipments 
        SET status = p_new_status,
            updated_at = NOW()
        WHERE id = p_shipment_id;

        -- Tracking events and fleet release handled reactively by triggers
        COMMIT;
        SET p_rows_affected = 1;
    ELSE
        ROLLBACK;
        SET p_rows_affected = 0;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 6. Stored Procedure: sp_calculate_driver_payout
-- Demonstrates CURSOR iterating over drivers to compute earnings
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_calculate_driver_payout(
    OUT p_total_drivers_processed INT,
    OUT p_total_payout_inr DECIMAL(12,2)
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_driver_id VARCHAR(36);
    DECLARE v_driver_name VARCHAR(100);
    DECLARE v_delivered_count INT;
    DECLARE v_total_km DECIMAL(10,2);
    DECLARE v_base_salary DECIMAL(10,2) DEFAULT 15000.00;
    DECLARE v_per_km_incentive DECIMAL(10,2) DEFAULT 3.50;
    DECLARE v_per_trip_bonus DECIMAL(10,2) DEFAULT 400.00;
    DECLARE v_driver_payout DECIMAL(12,2);

    -- Declare CURSOR
    DECLARE cur_drivers CURSOR FOR
        SELECT 
            d.id, 
            d.name,
            COUNT(s.id) AS delivered_trips,
            COALESCE(SUM(r.estimated_distance_km), 0.00) AS total_km
        FROM drivers d
        LEFT JOIN shipments s ON d.id = s.driver_id AND s.status = 'DELIVERED'
        LEFT JOIN routes r ON s.route_id = r.id
        GROUP BY d.id, d.name;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SET p_total_drivers_processed = 0;
    SET p_total_payout_inr = 0.00;

    DROP TEMPORARY TABLE IF EXISTS tmp_driver_payouts;
    CREATE TEMPORARY TABLE tmp_driver_payouts (
        driver_id VARCHAR(36),
        driver_name VARCHAR(100),
        completed_deliveries INT,
        total_distance_km DECIMAL(10,2),
        base_salary DECIMAL(10,2),
        trip_bonus DECIMAL(10,2),
        distance_incentive DECIMAL(10,2),
        net_payout_inr DECIMAL(12,2)
    );

    OPEN cur_drivers;

    read_loop: LOOP
        FETCH cur_drivers INTO v_driver_id, v_driver_name, v_delivered_count, v_total_km;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET v_driver_payout = v_base_salary + (v_delivered_count * v_per_trip_bonus) + (v_total_km * v_per_km_incentive);

        INSERT INTO tmp_driver_payouts VALUES (
            v_driver_id,
            v_driver_name,
            v_delivered_count,
            v_total_km,
            v_base_salary,
            (v_delivered_count * v_per_trip_bonus),
            (v_total_km * v_per_km_incentive),
            v_driver_payout
        );

        SET p_total_drivers_processed = p_total_drivers_processed + 1;
        SET p_total_payout_inr = p_total_payout_inr + v_driver_payout;
    END LOOP;

    CLOSE cur_drivers;

    SELECT * FROM tmp_driver_payouts ORDER BY net_payout_inr DESC;
END$$

-- ---------------------------------------------------------------------
-- 7. Stored Procedure: sp_audit_inventory_restock
-- Demonstrates CURSOR iterating over depleted warehouse items
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_audit_inventory_restock(
    OUT p_items_needing_restock INT,
    OUT p_estimated_procurement_cost DECIMAL(12,2)
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_id VARCHAR(36);
    DECLARE v_code VARCHAR(50);
    DECLARE v_name VARCHAR(255);
    DECLARE v_qty INT;
    DECLARE v_reorder INT;
    DECLARE v_cost DECIMAL(10,2);
    DECLARE v_item_deficit INT;
    DECLARE v_subtotal DECIMAL(12,2);

    DECLARE cur_inventory CURSOR FOR
        SELECT id, item_code, item_name, quantity, reorder_level, unit_cost
        FROM inventory
        WHERE quantity <= reorder_level;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SET p_items_needing_restock = 0;
    SET p_estimated_procurement_cost = 0.00;

    OPEN cur_inventory;

    audit_loop: LOOP
        FETCH cur_inventory INTO v_id, v_code, v_name, v_qty, v_reorder, v_cost;
        IF done THEN
            LEAVE audit_loop;
        END IF;

        SET v_item_deficit = (v_reorder - v_qty) + 10;
        SET v_subtotal = v_item_deficit * v_cost;

        SET p_items_needing_restock = p_items_needing_restock + 1;
        SET p_estimated_procurement_cost = p_estimated_procurement_cost + v_subtotal;
    END LOOP;

    CLOSE cur_inventory;

    INSERT INTO analytics_reports (id, report_type, generated_at, data)
    VALUES (
        UUID(),
        'INVENTORY_RESTOCK_AUDIT',
        NOW(),
        JSON_OBJECT(
            'depleted_items_count', p_items_needing_restock,
            'total_procurement_cost_inr', p_estimated_procurement_cost,
            'audited_at', NOW()
        )
    );
END$$

DELIMITER ;
