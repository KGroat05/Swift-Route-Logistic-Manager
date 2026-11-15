-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Transactions & Concurrency Control: 08_transactions_and_concurrency.sql
-- Engine: MySQL 8.4 LTS (InnoDB Engine)
-- =====================================================================

USE swiftroute;

-- =====================================================================
-- SCENARIO 1: ATOMICITY AND SAVEPOINT PARTIAL ROLLBACK DEMONSTRATION
-- Demonstrates partial rollback to savepoint when an optional step fails
-- =====================================================================

START TRANSACTION;

-- Step A: Insert a new customer
INSERT INTO customers (id, name, contact_name, contact_email, contact_phone, address, city, state, postal_code)
VALUES ('cst-test-01', 'Greenfield Agritech Ltd', 'Suresh Kumar', 'shipping@greenfield.in', '+91-9840999000', 'Warehouse 4, Maraimalai Nagar', 'Chennai', 'Tamil Nadu', '603209');

-- Establish Savepoint A
SAVEPOINT sp_customer_created;

-- Step B: Insert a corresponding shipment
INSERT INTO shipments (
    id, tracking_number, customer_id, origin_address, destination_address, 
    status, weight, volume, cargo_type, created_at
) VALUES (
    'shp-test-01', 'SR-2026-TEST-99', 'cst-test-01', 'Maraimalai Nagar Hub', 'Bengaluru South Depot',
    'PENDING', 1200.000, 4.000, 'Organic Produce', NOW()
);

-- Establish Savepoint B
SAVEPOINT sp_shipment_created;

-- Step C: Simulate an intentional erroneous operation
-- Rolling back to Savepoint B preserves the customer and shipment without losing work:
ROLLBACK TO SAVEPOINT sp_shipment_created;

-- Commit the verified parts of the transaction
COMMIT;

-- Verification of Scenario 1:
SELECT id, name FROM customers WHERE id = 'cst-test-01';
SELECT id, tracking_number, status FROM shipments WHERE id = 'shp-test-01';

-- Clean up test records
DELETE FROM shipments WHERE id = 'shp-test-01';
DELETE FROM customers WHERE id = 'cst-test-01';


-- =====================================================================
-- SCENARIO 2: PESSIMISTIC CONCURRENCY CONTROL (SELECT ... FOR UPDATE)
-- Demonstrates Two-Phase Locking (2PL) to prevent concurrent double-booking
-- of the same delivery vehicle by two concurrent dispatchers.
-- =====================================================================

-- Dispatcher Session 1:
START TRANSACTION;

-- Lock the target vehicle row exclusively
SELECT id, license_plate, model, status, capacity_kg
FROM vehicles
WHERE id = 'veh-003' AND status = 'AVAILABLE'
FOR UPDATE;

-- While this transaction is open, any concurrent transaction attempting
-- `SELECT ... WHERE id = 'veh-003' FOR UPDATE` will block until this transaction commits.

-- Dispatcher 1 successfully reserves vehicle
UPDATE vehicles SET status = 'IN_USE' WHERE id = 'veh-003';

-- Commit locks and release row
COMMIT;

-- Reset vehicle for subsequent operations
UPDATE vehicles SET status = 'AVAILABLE' WHERE id = 'veh-003';


-- =====================================================================
-- SCENARIO 3: SHARED LOCKING (SELECT ... FOR SHARE)
-- Multiple readers can read consistent snapshot without blocking each other,
-- but writers attempting FOR UPDATE will wait until shared locks release.
-- =====================================================================

START TRANSACTION;

-- Read invoice with shared read lock
SELECT id, invoice_number, total_amount, status
FROM invoices
WHERE status = 'UNPAID'
FOR SHARE;

COMMIT;


-- =====================================================================
-- SCENARIO 4: REPEATABLE READ TRANSACTION ISOLATION
-- InnoDB default isolation level is REPEATABLE READ.
-- Ensures consistent read view across queries within the same transaction.
-- =====================================================================

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

START TRANSACTION;

-- Read snapshot 1
SELECT COUNT(*) AS active_shipment_count FROM shipments WHERE status = 'IN_TRANSIT';

-- Even if another transaction commits new IN_TRANSIT shipments concurrently,
-- InnoDB Multi-Version Concurrency Control (MVCC) returns the exact same snapshot:
SELECT COUNT(*) AS active_shipment_count_mvcc FROM shipments WHERE status = 'IN_TRANSIT';

COMMIT;


-- =====================================================================
-- SCENARIO 5: INNODB ENGINE DEADLOCK DETECTION & ENGINE STATUS
-- =====================================================================
SHOW ENGINE INNODB STATUS;
