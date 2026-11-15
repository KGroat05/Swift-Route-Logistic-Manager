-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Database Triggers: 03_triggers.sql
-- Engine: MySQL 8.4 LTS
-- =====================================================================

USE swiftroute;

DROP TRIGGER IF EXISTS trg_after_shipment_insert;
DROP TRIGGER IF EXISTS trg_before_shipment_update;
DROP TRIGGER IF EXISTS trg_after_shipment_status_update;
DROP TRIGGER IF EXISTS trg_prevent_busy_driver_assignment;
DROP TRIGGER IF EXISTS trg_invoice_payment_sync;
DROP TRIGGER IF EXISTS trg_inventory_check_zero;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. Trigger: trg_after_shipment_insert
-- Automatically logs the initial tracking event upon shipment booking
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_after_shipment_insert
AFTER INSERT ON shipments
FOR EACH ROW
BEGIN
    INSERT INTO tracking_events (
        id, shipment_id, event_time, location, status, notes, created_by
    ) VALUES (
        UUID(),
        NEW.id,
        NOW(),
        SUBSTRING(NEW.origin_address, 1, 250),
        NEW.status,
        CONCAT('Initial booking created for shipment #', NEW.tracking_number, '. Status: ', NEW.status),
        'AUTO_TRIGGER'
    );
END$$

-- ---------------------------------------------------------------------
-- 2. Trigger: trg_before_shipment_update
-- Validates strict state transitions and prevents illegal status regressions
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_before_shipment_update
BEFORE UPDATE ON shipments
FOR EACH ROW
BEGIN
    -- Only validate if status is actually changing
    IF OLD.status <> NEW.status THEN
        -- Rule 1: DELIVERED is a terminal state
        IF OLD.status = 'DELIVERED' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Status Error: A DELIVERED shipment cannot transition to any other status.';
        END IF;

        -- Rule 2: CANCELLED is a terminal state
        IF OLD.status = 'CANCELLED' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Status Error: A CANCELLED shipment cannot transition to any other status.';
        END IF;

        -- Rule 3: Validate permissible transitions
        IF OLD.status = 'PENDING' AND NEW.status NOT IN ('BOOKED', 'CANCELLED') THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Status Error: PENDING shipments can only transition to BOOKED or CANCELLED.';
        ELSEIF OLD.status = 'BOOKED' AND NEW.status NOT IN ('IN_TRANSIT', 'CANCELLED') THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Status Error: BOOKED shipments can only transition to IN_TRANSIT or CANCELLED.';
        ELSEIF OLD.status = 'IN_TRANSIT' AND NEW.status NOT IN ('OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED') THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Status Error: IN_TRANSIT shipments can only transition to OUT_FOR_DELIVERY, DELIVERED, or CANCELLED.';
        ELSEIF OLD.status = 'OUT_FOR_DELIVERY' AND NEW.status NOT IN ('DELIVERED', 'IN_TRANSIT', 'CANCELLED') THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Status Error: OUT_FOR_DELIVERY shipments can only transition to DELIVERED, IN_TRANSIT, or CANCELLED.';
        END IF;

        -- Rule 4: Automatically populate actual_delivery timestamp upon DELIVERED
        IF NEW.status = 'DELIVERED' AND OLD.status <> 'DELIVERED' THEN
            SET NEW.actual_delivery = NOW();
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 3. Trigger: trg_after_shipment_status_update
-- Logs milestone tracking event and releases fleet resources on terminal status
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_after_shipment_status_update
AFTER UPDATE ON shipments
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        -- Add milestone tracking event
        INSERT INTO tracking_events (
            id, shipment_id, event_time, location, status, notes, created_by
        ) VALUES (
            UUID(),
            NEW.id,
            NOW(),
            CASE 
                WHEN NEW.status = 'DELIVERED' THEN SUBSTRING(NEW.destination_address, 1, 250)
                ELSE 'Transit Hub / Waypoint'
            END,
            NEW.status,
            CONCAT('Status automatically transitioned from [', OLD.status, '] to [', NEW.status, '].'),
            'STATUS_TRIGGER'
        );

        -- If terminal state (DELIVERED or CANCELLED), release assigned vehicle and driver
        IF NEW.status IN ('DELIVERED', 'CANCELLED') THEN
            IF NEW.vehicle_id IS NOT NULL THEN
                UPDATE vehicles SET status = 'AVAILABLE' WHERE id = NEW.vehicle_id;
            END IF;
            IF NEW.driver_id IS NOT NULL THEN
                UPDATE drivers SET status = 'ACTIVE' WHERE id = NEW.driver_id;
            END IF;
            -- Mark related active driver assignment as completed/cancelled
            UPDATE driver_assignments
            SET status = CASE WHEN NEW.status = 'DELIVERED' THEN 'COMPLETED' ELSE 'CANCELLED' END,
                shift_end = NOW()
            WHERE driver_id = NEW.driver_id AND vehicle_id = NEW.vehicle_id AND status IN ('SCHEDULED', 'ONGOING');
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 4. Trigger: trg_prevent_busy_driver_assignment
-- Enforces concurrency control: Prevents assigning drivers or vehicles
-- that are already allocated to active or scheduled shifts on the same date.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_prevent_busy_driver_assignment
BEFORE INSERT ON driver_assignments
FOR EACH ROW
BEGIN
    -- Check if the driver is already booked for an active shift on this assignment date
    IF NEW.status IN ('SCHEDULED', 'ONGOING') THEN
        IF EXISTS (
            SELECT 1 FROM driver_assignments 
            WHERE driver_id = NEW.driver_id 
              AND assignment_date = NEW.assignment_date 
              AND status IN ('SCHEDULED', 'ONGOING')
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Concurrency Conflict: Driver is already assigned to an active shift on this date.';
        END IF;

        -- Check if the vehicle is already booked for an active shift on this assignment date
        IF EXISTS (
            SELECT 1 FROM driver_assignments 
            WHERE vehicle_id = NEW.vehicle_id 
              AND assignment_date = NEW.assignment_date 
              AND status IN ('SCHEDULED', 'ONGOING')
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Concurrency Conflict: Vehicle is already scheduled for another dispatch on this date.';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 5. Trigger: trg_invoice_payment_sync
-- Synchronizes paid_at timestamp when invoice status changes to PAID
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_invoice_payment_sync
BEFORE UPDATE ON invoices
FOR EACH ROW
BEGIN
    IF NEW.status = 'PAID' AND OLD.status <> 'PAID' AND NEW.paid_at IS NULL THEN
        SET NEW.paid_at = NOW();
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 6. Trigger: trg_inventory_check_zero
-- Prevents inventory quantities from being updated to negative values
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_inventory_check_zero
BEFORE UPDATE ON inventory
FOR EACH ROW
BEGIN
    IF NEW.quantity < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Constraint Violation: Inventory stock level cannot be negative.';
    END IF;
END$$

DELIMITER ;
