-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Database Triggers: 05_triggers.sql
-- Engine: MySQL 8.4 LTS
-- =====================================================================

USE swiftroute;

DROP TRIGGER IF EXISTS trg_after_shipment_insert;
DROP TRIGGER IF EXISTS trg_after_shipment_update;
DROP TRIGGER IF EXISTS trg_enforce_shipment_weight_check;
DROP TRIGGER IF EXISTS trg_invoice_payment_sync;
DROP TRIGGER IF EXISTS trg_inventory_check_zero;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. Trigger: trg_enforce_shipment_weight_check
-- BEFORE INSERT: Validates cargo weight constraint
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_enforce_shipment_weight_check
BEFORE INSERT ON shipments
FOR EACH ROW
BEGIN
    IF NEW.weight <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Validation Error: Shipment weight must be greater than 0 kg.';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 2. Trigger: trg_after_shipment_insert
-- AFTER INSERT: Automatically logs initial tracking event
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
        SUBSTRING(NEW.origin_address, 1, 200),
        NEW.status,
        CONCAT('Shipment booking registered in system with tracking #', NEW.tracking_number, '. Initial status: ', NEW.status),
        'AUTO_TRIGGER'
    );
END$$

-- ---------------------------------------------------------------------
-- 3. Trigger: trg_after_shipment_update
-- AFTER UPDATE: Automatically creates audit trail on status transitions
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_after_shipment_update
AFTER UPDATE ON shipments
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO tracking_events (
            id, shipment_id, event_time, location, status, notes, created_by
        ) VALUES (
            UUID(),
            NEW.id,
            NOW(),
            CASE 
                WHEN NEW.status = 'DELIVERED' THEN SUBSTRING(NEW.destination_address, 1, 200)
                ELSE 'Transit Checkpoint'
            END,
            NEW.status,
            CONCAT('Status automatically transitioned from [', OLD.status, '] to [', NEW.status, '].'),
            'STATUS_TRIGGER'
        );
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 4. Trigger: trg_invoice_payment_sync
-- BEFORE UPDATE: Automatically sets paid_at timestamp when invoice marked PAID
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_invoice_payment_sync
BEFORE UPDATE ON billing
FOR EACH ROW
BEGIN
    IF NEW.status = 'PAID' AND OLD.status <> 'PAID' AND NEW.paid_at IS NULL THEN
        SET NEW.paid_at = NOW();
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 5. Trigger: trg_inventory_check_zero
-- BEFORE UPDATE: Prevents inventory balance from ever going negative
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_inventory_check_zero
BEFORE UPDATE ON inventory
FOR EACH ROW
BEGIN
    IF NEW.quantity < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity Constraint Error: Inventory stock level cannot be negative.';
    END IF;
END$$

DELIMITER ;
