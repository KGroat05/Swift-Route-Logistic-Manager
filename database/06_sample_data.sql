-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Seed Sample Data: 06_sample_data.sql
-- Engine: MySQL 8.4 LTS
-- =====================================================================

USE swiftroute;

-- ---------------------------------------------------------------------
-- 1. Seed Users (Default credentials: password matches username + "123")
-- ---------------------------------------------------------------------
INSERT INTO users (id, username, email, password_hash, full_name, role, is_active, created_at)
VALUES
('usr-001', 'admin', 'admin@swiftroute.internal', '$2b$12$cWc1tEZB4KdWu/3WRZwRUuUn/1O2WD4aD0.DcbxWnsHgypiUxpUze', 'Krishang Gupta (System Admin)', 'ADMIN', TRUE, NOW()),
('usr-002', 'dispatcher', 'dispatcher@swiftroute.internal', '$2b$12$kOz/PBGYZv2xWMq7SqCFneccjZlJDAqlBOYLvCqi546gTVzrElNDi', 'Arun Kumar (Chief Dispatcher)', 'DISPATCHER', TRUE, NOW()),
('usr-003', 'viewer', 'viewer@swiftroute.internal', '$2b$12$2isDpAhfP6bVKVqf7mCyEuXbn/8lJwO8mkklSChuj77rW9kuHDMm.', 'Priya Sharma (Auditor / Viewer)', 'VIEWER', TRUE, NOW())
ON DUPLICATE KEY UPDATE updated_at = NOW();

-- ---------------------------------------------------------------------
-- 2. Seed Customers
-- ---------------------------------------------------------------------
INSERT INTO customers (id, name, contact_name, contact_email, contact_phone, address, city, state, postal_code)
VALUES
('cst-001', 'Tata Electronics Pvt Ltd', 'Ramesh Sundaram', 'procurement@tataelectronics.in', '+91-9840112233', 'Plot 45, Sipcot Industrial Complex, Hosur', 'Hosur', 'Tamil Nadu', '635126'),
('cst-002', 'Flipkart Logistics Hub', 'Ananya Deshmukh', 'hub.chennai@flipkart.com', '+91-9840223344', 'Warehouse 12, GNT Road, Madhavaram', 'Chennai', 'Tamil Nadu', '600060'),
('cst-003', 'Apollo Healthcare Supplies', 'Dr. S. K. Venkat', 'logistics@apollohospitals.com', '+91-9840334455', '21 Greams Lane, Thousand Lights', 'Chennai', 'Tamil Nadu', '600006'),
('cst-004', 'Reliance Retail Distribution', 'Mukesh Agarwal', 'supplychain@relianceretail.com', '+91-9840445566', 'Survey 88, Outer Ring Road, Vandalur', 'Chennai', 'Tamil Nadu', '600048'),
('cst-005', 'Zoho Hardware Engineering', 'Sridhar Narayan', 'infra@zohocorp.com', '+91-9840556677', 'Estancia IT Park, Guduvanchery', 'Chennai', 'Tamil Nadu', '603202'),
('cst-006', 'Ashok Leyland Spares Depot', 'B. K. Natarajan', 'parts.dispatch@ashokleyland.com', '+91-9840667788', '1 Sardar Patel Road, Guindy', 'Chennai', 'Tamil Nadu', '600032'),
('cst-007', 'Bharat Electronics Limited', 'Commander V. Rao', 'shipping@bel-india.co.in', '+91-9840778899', 'Nandambakkam Industrial Area', 'Chennai', 'Tamil Nadu', '600089'),
('cst-008', 'Chennai Port Transshipment Hub', 'Capt. Mohan Raj', 'cargo@chennaiport.gov.in', '+91-9840889900', 'Rajaji Salai, George Town', 'Chennai', 'Tamil Nadu', '600001')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ---------------------------------------------------------------------
-- 3. Seed Routes
-- ---------------------------------------------------------------------
INSERT INTO routes (id, name, start_location, end_location, estimated_distance_km, estimated_time_minutes, toll_charges)
VALUES
('rt-001', 'Chennai to Bengaluru Corridor', 'Chennai Central Depot', 'Bengaluru Electronic City Hub', 348.50, 360, 420.00),
('rt-002', 'Chennai to Hyderabad Expressway', 'Chennai Central Depot', 'Hyderabad Shamshabad Logistics Park', 625.00, 600, 780.00),
('rt-003', 'Chennai to Coimbatore Industrial Line', 'Chennai Central Depot', 'Coimbatore Peelamedu Goods Terminal', 505.20, 480, 560.00),
('rt-004', 'Bengaluru to Mumbai Western Route', 'Bengaluru Electronic City Hub', 'Mumbai Bhiwandi Logistics Complex', 980.00, 960, 1250.00),
('rt-005', 'Chennai to Madurai Express Route', 'Chennai Central Depot', 'Madurai Ring Road Cargo Terminal', 460.00, 420, 510.00),
('rt-006', 'Chennai Metro Local Transit', 'Madhavaram Hub', 'Siruseri IT Corridor Hub', 45.00, 90, 80.00),
('rt-007', 'Delhi to Jaipur Golden Corridor', 'Delhi Okhla Terminal', 'Jaipur Transport Nagar', 280.00, 300, 350.00)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ---------------------------------------------------------------------
-- 4. Seed Vehicles
-- ---------------------------------------------------------------------
INSERT INTO vehicles (id, license_plate, model, vehicle_type, capacity_kg, capacity_m3, status, last_maintenance_date)
VALUES
('veh-001', 'TN-01-AB-1001', 'Tata Prima 4028.S', 'HEAVY_TRUCK', 28000.00, 65.00, 'AVAILABLE', '2026-09-15'),
('veh-002', 'TN-02-CD-2002', 'Ashok Leyland Ecomet 1215', 'LIGHT_TRUCK', 11500.00, 32.00, 'IN_USE', '2026-09-28'),
('veh-003', 'KA-05-EF-3003', 'Mahindra Furio 7', 'LIGHT_TRUCK', 7000.00, 22.00, 'AVAILABLE', '2026-10-02'),
('veh-004', 'TN-07-GH-4004', 'Tata Ace Gold EV', 'MINI_VAN', 1200.00, 6.50, 'IN_USE', '2026-10-10'),
('veh-005', 'MH-04-JK-5005', 'BharatBenz 2823C', 'HEAVY_TRUCK', 25000.00, 58.00, 'AVAILABLE', '2026-08-20'),
('veh-006', 'DL-01-LM-6006', 'Volvo FH 520 Multi-Axle', 'CONTAINER', 35000.00, 85.00, 'AVAILABLE', '2026-09-01'),
('veh-007', 'TN-09-NP-7007', 'Ashok Leyland Bada Dost', 'MINI_VAN', 1800.00, 9.00, 'MAINTENANCE', '2026-10-18'),
('veh-008', 'KA-03-QR-8008', 'Eicher Pro 2049', 'LIGHT_TRUCK', 4900.00, 16.00, 'AVAILABLE', '2026-09-12')
ON DUPLICATE KEY UPDATE model = VALUES(model);

-- ---------------------------------------------------------------------
-- 5. Seed Drivers
-- ---------------------------------------------------------------------
INSERT INTO drivers (id, name, license_number, phone, email, status, hired_date, experience_years)
VALUES
('drv-001', 'Murugan Palaniswamy', 'DL-TN-01-2015-0019283', '+91-9444101010', 'murugan.p@swiftroute.internal', 'ACTIVE', '2021-03-15', 9),
('drv-002', 'Karthik Selvaraj', 'DL-TN-02-2018-0048291', '+91-9444202020', 'karthik.s@swiftroute.internal', 'ON_DUTY', '2022-07-01', 6),
('drv-003', 'Suresh Babu Naidu', 'DL-AP-03-2014-0091823', '+91-9444303030', 'suresh.naidu@swiftroute.internal', 'ACTIVE', '2020-01-10', 12),
('drv-004', 'Manoj Gowda', 'DL-KA-05-2019-0038172', '+91-9444404040', 'manoj.gowda@swiftroute.internal', 'ON_DUTY', '2023-04-18', 5),
('drv-005', 'Dinesh Chandran', 'DL-TN-09-2016-0055198', '+91-9444505050', 'dinesh.c@swiftroute.internal', 'ACTIVE', '2021-11-20', 8),
('drv-006', 'Rajendra Patil', 'DL-MH-04-2012-0077281', '+91-9444606060', 'rajendra.patil@swiftroute.internal', 'ACTIVE', '2019-08-14', 14),
('drv-007', 'Deepak Verma', 'DL-DL-01-2020-0011928', '+91-9444707070', 'deepak.verma@swiftroute.internal', 'ON_LEAVE', '2024-02-01', 4)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ---------------------------------------------------------------------
-- 6. Seed Driver Assignments (Respects concurrency constraint: unique driver & vehicle per date)
-- ---------------------------------------------------------------------
INSERT INTO driver_assignments (id, driver_id, vehicle_id, route_id, assignment_date, shift_start, shift_end, status)
VALUES
('asg-001', 'drv-002', 'veh-002', 'rt-001', '2026-10-19', '2026-10-19 06:00:00', '2026-10-19 18:00:00', 'ONGOING'),
('asg-002', 'drv-004', 'veh-004', 'rt-006', '2026-10-20', '2026-10-20 08:00:00', '2026-10-20 17:00:00', 'ONGOING'),
('asg-003', 'drv-001', 'veh-001', 'rt-002', '2026-10-18', '2026-10-18 05:00:00', '2026-10-18 20:00:00', 'COMPLETED'),
('asg-004', 'drv-003', 'veh-003', 'rt-003', '2026-10-21', '2026-10-21 06:00:00', '2026-10-21 18:00:00', 'SCHEDULED'),
('asg-005', 'drv-006', 'veh-005', 'rt-004', '2026-10-15', '2026-10-15 04:00:00', '2026-10-16 02:00:00', 'COMPLETED')
ON DUPLICATE KEY UPDATE status = VALUES(status);

-- ---------------------------------------------------------------------
-- 7. Seed Shipments (Trigger trg_after_shipment_insert auto-creates initial tracking events)
-- ---------------------------------------------------------------------
INSERT INTO shipments (id, tracking_number, customer_id, origin_address, destination_address, scheduled_pickup, scheduled_delivery, actual_delivery, status, weight, volume, cargo_type, route_id, driver_id, vehicle_id, created_at)
VALUES
('shp-1001', 'SR-2026-1001', 'cst-001', 'Plot 45, Sipcot Complex, Hosur', 'Electronic City Phase 1, Bengaluru', '2026-10-19 07:30:00', '2026-10-19 16:30:00', NULL, 'IN_TRANSIT', 4500.000, 14.500, 'Automotive Semiconductor Parts', 'rt-001', 'drv-002', 'veh-002', '2026-10-18 14:00:00'),
('shp-1002', 'SR-2026-1002', 'cst-002', 'Madhavaram Hub, Chennai', 'Siruseri IT Corridor Hub, Chennai', '2026-10-20 09:00:00', '2026-10-20 14:00:00', NULL, 'OUT_FOR_DELIVERY', 680.000, 4.200, 'Consumer Electronics & Mobiles', 'rt-006', 'drv-004', 'veh-004', '2026-10-19 18:30:00'),
('shp-1003', 'SR-2026-1003', 'cst-003', '21 Greams Lane, Chennai', 'Apollo Speciality, Madurai', '2026-10-17 08:00:00', '2026-10-17 19:00:00', '2026-10-17 18:25:00', 'DELIVERED', 1250.000, 5.800, 'Cold-Chain Medical Vaccines', 'rt-005', 'drv-005', 'veh-003', '2026-10-16 11:00:00'),
('shp-1004', 'SR-2026-1004', 'cst-004', 'Vandalur Warehouse, Chennai', 'Shamshabad Distribution Park, Hyderabad', '2026-10-18 06:00:00', '2026-10-19 08:00:00', '2026-10-19 07:45:00', 'DELIVERED', 18500.000, 42.000, 'FMCG Packaged Foods', 'rt-002', 'drv-001', 'veh-001', '2026-10-17 09:15:00'),
('shp-1005', 'SR-2026-1005', 'cst-005', 'Estancia IT Park, Guduvanchery', 'Whitefield Tech Zone, Bengaluru', '2026-10-21 10:00:00', '2026-10-21 20:00:00', NULL, 'BOOKED', 2100.000, 8.000, 'Server Racks and Network Switches', 'rt-001', 'drv-003', 'veh-003', '2026-10-20 08:30:00'),
('shp-1006', 'SR-2026-1006', 'cst-006', '1 Sardar Patel Road, Guindy', 'Peelamedu Depot, Coimbatore', '2026-10-22 07:00:00', '2026-10-22 18:00:00', NULL, 'PENDING', 3800.000, 11.200, 'Commercial Vehicle Engine Blocks', 'rt-003', NULL, NULL, '2026-10-20 10:00:00'),
('shp-1007', 'SR-2026-1007', 'cst-007', 'Nandambakkam Industrial Area', 'HAL Aerospace Division, Bengaluru', '2026-10-16 09:00:00', '2026-10-16 21:00:00', '2026-10-16 20:40:00', 'DELIVERED', 5200.000, 15.000, 'Defense Avionics Modules', 'rt-001', 'drv-001', 'veh-001', '2026-10-15 12:00:00'),
('shp-1008', 'SR-2026-1008', 'cst-008', 'Chennai Port Gate 4', 'Bhiwandi Freight Hub, Mumbai', '2026-10-12 06:00:00', '2026-10-14 18:00:00', '2026-10-14 17:15:00', 'DELIVERED', 22000.000, 50.000, 'Imported Solar Panels & Inverters', 'rt-004', 'drv-006', 'veh-005', '2026-10-11 16:00:00'),
('shp-1009', 'SR-2026-1009', 'cst-002', 'Madhavaram Hub, Chennai', 'Velachery Mini Hub, Chennai', '2026-10-19 14:00:00', '2026-10-19 18:00:00', NULL, 'CANCELLED', 150.000, 1.200, 'Damaged Return Items', 'rt-006', NULL, NULL, '2026-10-19 11:00:00')
ON DUPLICATE KEY UPDATE status = VALUES(status);

-- ---------------------------------------------------------------------
-- 8. Seed Tracking Events (Detailed milestone checkpoints)
-- ---------------------------------------------------------------------
INSERT INTO tracking_events (id, shipment_id, event_time, location, status, notes, created_by)
VALUES
('trv-001', 'shp-1001', '2026-10-18 14:00:00', 'Hosur Logistics Desk', 'BOOKED', 'Shipment order booked by customer Tata Electronics.', 'DISPATCHER'),
('trv-002', 'shp-1001', '2026-10-19 07:45:00', 'Hosur Sipcot Hub', 'IN_TRANSIT', 'Loaded onto Ashok Leyland Ecomet (TN-02-CD-2002). Departed for Bengaluru.', 'DRIVER_APP'),
('trv-003', 'shp-1001', '2026-10-19 12:15:00', 'Attibele Border Toll', 'IN_TRANSIT', 'Cleared inter-state commercial toll checkpoint. Moving smooth.', 'AUTOMATION'),

('trv-004', 'shp-1002', '2026-10-19 18:30:00', 'Madhavaram Hub', 'BOOKED', 'Order consolidated and tagged for morning distribution.', 'SYSTEM'),
('trv-005', 'shp-1002', '2026-10-20 09:10:00', 'Madhavaram Hub', 'IN_TRANSIT', 'Loaded into Tata Ace Gold EV. Departed.', 'DISPATCHER'),
('trv-006', 'shp-1002', '2026-10-20 10:45:00', 'OMR Toll Plaza', 'OUT_FOR_DELIVERY', 'Shipment is out for delivery to Siruseri IT Corridor.', 'DRIVER_APP'),

('trv-007', 'shp-1003', '2026-10-16 11:00:00', 'Greams Road Depot', 'BOOKED', 'Medical vaccine booking confirmed with cold-chain requirement.', 'SYSTEM'),
('trv-008', 'shp-1003', '2026-10-17 08:15:00', 'Greams Road Depot', 'IN_TRANSIT', 'Temperature logger calibrated at 4 deg Celsius. Departed.', 'DISPATCHER'),
('trv-009', 'shp-1003', '2026-10-17 18:25:00', 'Apollo Speciality Madurai', 'DELIVERED', 'Delivered intact. Signed by Pharmacist Dr. N. Murthi.', 'SYSTEM'),

('trv-010', 'shp-1004', '2026-10-17 09:15:00', 'Vandalur Warehouse', 'BOOKED', 'Bulk shipment registered for Hyderabad.', 'SYSTEM'),
('trv-011', 'shp-1004', '2026-10-18 06:30:00', 'Vandalur Warehouse', 'IN_TRANSIT', 'Dispatched on Tata Prima 4028.S.', 'DISPATCHER'),
('trv-012', 'shp-1004', '2026-10-19 07:45:00', 'Shamshabad Distribution Park', 'DELIVERED', 'Full payload received and unloaded.', 'SYSTEM'),

('trv-013', 'shp-1005', '2026-10-20 08:30:00', 'Guduvanchery Hub', 'BOOKED', 'Scheduled for pickup tomorrow 10:00 AM.', 'DISPATCHER'),
('trv-014', 'shp-1006', '2026-10-20 10:00:00', 'Guindy Parts Depot', 'PENDING', 'Awaiting carrier assignment.', 'SYSTEM')
ON DUPLICATE KEY UPDATE notes = VALUES(notes);

-- ---------------------------------------------------------------------
-- 9. Seed Invoices
-- ---------------------------------------------------------------------
INSERT INTO invoices (id, invoice_number, shipment_id, customer_id, amount, tax_amount, currency, billing_date, due_date, status, payment_method, paid_at)
VALUES
('inv-001', 'INV-2026-00101', 'shp-1001', 'cst-001', 34500.00, 6210.00, 'INR', '2026-10-18', '2026-11-02', 'UNPAID', NULL, NULL),
('inv-002', 'INV-2026-00102', 'shp-1002', 'cst-002', 8200.00, 1476.00, 'INR', '2026-10-19', '2026-11-03', 'PAID', 'UPI', '2026-10-20 09:30:00'),
('inv-003', 'INV-2026-00103', 'shp-1003', 'cst-003', 21000.00, 3780.00, 'INR', '2026-10-16', '2026-10-31', 'PAID', 'NEFT', '2026-10-17 19:10:00'),
('inv-004', 'INV-2026-00104', 'shp-1004', 'cst-004', 68000.00, 12240.00, 'INR', '2026-10-17', '2026-10-24', 'PAID', 'NEFT', '2026-10-19 11:20:00'),
('inv-005', 'INV-2026-00105', 'shp-1005', 'cst-005', 24000.00, 4320.00, 'INR', '2026-10-20', '2026-11-04', 'UNPAID', NULL, NULL),
('inv-006', 'INV-2026-00106', 'shp-1007', 'cst-007', 48000.00, 8640.00, 'INR', '2026-10-15', '2026-10-22', 'PAID', 'NEFT', '2026-10-16 16:00:00'),
('inv-007', 'INV-2026-00107', 'shp-1008', 'cst-008', 115000.00, 20700.00, 'INR', '2026-10-11', '2026-10-18', 'OVERDUE', NULL, NULL)
ON DUPLICATE KEY UPDATE status = VALUES(status);

-- ---------------------------------------------------------------------
-- 10. Seed Inventory (Warehouse Packaging Supplies & Stock)
-- ---------------------------------------------------------------------
INSERT INTO inventory (id, item_code, item_name, description, category, quantity, unit_of_measure, reorder_level, unit_cost, location)
VALUES
('inv-001', 'PKG-CRD-01', 'Heavy Duty 5-Ply Corrugated Box (L)', 'Reinforced 60x40x40cm shipping boxes', 'Packaging Material', 450, 'Boxes', 100, 65.00, 'Chennai Central - Bay A1'),
('inv-002', 'PKG-PLT-02', 'Standard Euro Wooden Pallet (1200x800)', 'ISPM-15 heat treated export wooden pallet', 'Pallets & Skids', 85, 'Pallets', 25, 650.00, 'Chennai Central - Yard 2'),
('inv-003', 'SEC-SL-03', 'Tamper-Evident High-Security Bolt Seal', 'ISO 17712 certified container security seals', 'Security & Seals', 1200, 'Pieces', 300, 28.50, 'Chennai Central - Vault B'),
('inv-004', 'PKG-BBL-04', 'Air Cushion Bubble Wrap (100m Roll)', 'Shock absorbing 10mm bubble diameter roll', 'Packaging Material', 18, 'Rolls', 20, 480.00, 'Chennai Central - Bay A2'),
('inv-005', 'TRK-TAG-05', 'Active UHF RFID Cargo Tracking Tag', 'EPC Gen2 passive/active hybrid smart tracking tags', 'Electronics & IoT', 320, 'Tags', 50, 115.00, 'Chennai Central - Tech Room'),
('inv-006', 'STR-PET-06', 'Heavy Duty Polyester Strapping Band (19mm)', 'High tensile breaking strength strapping coil', 'Securing Material', 12, 'Coils', 15, 850.00, 'Chennai Central - Bay A3'),
('inv-007', 'COLD-ICE-07', 'PCM Cold Chain Gel Ice Packs (-20C)', 'Reusable temperature stabilization refrigerant pack', 'Cold Chain', 140, 'Packs', 50, 42.00, 'Chennai Central - Cold Room')
ON DUPLICATE KEY UPDATE quantity = VALUES(quantity);

-- ---------------------------------------------------------------------
-- 11. Seed Partner Integrations
-- ---------------------------------------------------------------------
INSERT INTO partner_integrations (id, partner_name, integration_type, api_endpoint, auth_token, status, last_sync)
VALUES
('prt-001', 'BlueDart Tracking Gateway', 'TRACKING_API', 'https://api.bluedart.example/v2/track', 'tok_bluedart_99182a', 'ACTIVE', NOW()),
('prt-002', 'Delhivery Surface Dispatch', '3PL_DISPATCH', 'https://track.delhivery.example/api/p/pack', 'tok_delhivery_38127b', 'ACTIVE', NOW()),
('prt-003', 'Razorpay Corporate Invoicing', 'BILLING_GATEWAY', 'https://api.razorpay.example/v1/invoices', 'tok_razorpay_live_882', 'ACTIVE', NOW()),
('prt-004', 'Fastag Electronic Toll Sync', 'TRACKING_API', 'https://fastag.netc.example/transit/sync', 'tok_fastag_corp_5541', 'ACTIVE', NOW())
ON DUPLICATE KEY UPDATE status = VALUES(status);

-- ---------------------------------------------------------------------
-- 12. Seed Analytics Reports
-- ---------------------------------------------------------------------
INSERT INTO analytics_reports (id, report_type, generated_at, data, related_shipment_id, related_driver_id, related_vehicle_id, related_event_id)
VALUES
('anl-001', 'FLEET_EFFICIENCY_MONTHLY', NOW(), JSON_OBJECT(
    'period', '2026-10',
    'total_shipments', 9,
    'delivered_shipments', 4,
    'in_transit', 2,
    'total_revenue_inr', 318700.00,
    'average_delay_minutes', 0,
    'fuel_efficiency_km_l', 4.2
), NULL, NULL, NULL, NULL),
('anl-002', 'DRIVER_LEADERBOARD', NOW(), JSON_OBJECT(
    'top_driver_id', 'drv-001',
    'top_driver_name', 'Murugan Palaniswamy',
    'completed_deliveries', 2,
    'on_time_percentage', 100.0
), NULL, 'drv-001', NULL, NULL);
