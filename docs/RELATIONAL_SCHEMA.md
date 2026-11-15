# Relational Schema Specification
## Swift Route Logistics Manager
**Engine:** MySQL 8.4 LTS  
**Character Set:** `utf8mb4`  
**Collation:** `utf8mb4_unicode_ci`  
**Storage Engine:** InnoDB  

---

## 1. Table Definitions

### 1.1 `users` (Authentication & RBAC)
| Column | Type | Nullable | Key | Default | Description |
|---|---|---|---|---|---|
| `id` | VARCHAR(36) | NO | PK | - | Primary Key (UUID v4) |
| `username` | VARCHAR(50) | NO | UNI | - | Unique login username |
| `email` | VARCHAR(100) | NO | UNI | - | Unique email address |
| `password_hash` | VARCHAR(255) | NO | - | - | Bcrypt hashed credentials |
| `full_name` | VARCHAR(100) | NO | - | - | Operator display name |
| `role` | ENUM | NO | - | 'VIEWER' | RBAC: 'ADMIN', 'DISPATCHER', 'VIEWER' |
| `is_active` | BOOLEAN | NO | - | TRUE | Soft-delete / account lock flag |
| `created_at` | DATETIME | NO | - | CURRENT_TIMESTAMP | Timestamp of registration |
| `updated_at` | DATETIME | NO | - | CURRENT_TIMESTAMP | Auto-updating timestamp |

### 1.2 `customers`
| Column | Type | Nullable | Key | Default | Description |
|---|---|---|---|---|---|
| `id` | VARCHAR(36) | NO | PK | - | Customer UUID |
| `name` | VARCHAR(255) | NO | - | - | Corporate entity or client name |
| `contact_name` | VARCHAR(255) | YES | - | NULL | Point of contact person |
| `contact_email`| VARCHAR(255) | NO | UNI | - | Customer procurement email |
| `contact_phone`| VARCHAR(50)  | NO | - | - | Contact phone number |
| `address` | TEXT | NO | - | - | Billing / physical premises |
| `city` | VARCHAR(100) | YES | - | 'Chennai' | City |
| `state` | VARCHAR(100) | YES | - | 'Tamil Nadu' | State |
| `postal_code` | VARCHAR(20) | YES | - | '600001' | Postal PIN code |
| `created_at` | DATETIME | NO | - | CURRENT_TIMESTAMP | Account creation timestamp |

### 1.3 `routes`
| Column | Type | Nullable | Key | Default | Description |
|---|---|---|---|---|---|
| `id` | VARCHAR(36) | NO | PK | - | Route UUID |
| `name` | VARCHAR(100) | NO | - | - | Route title (e.g. Chennai - Bengaluru) |
| `start_location` | VARCHAR(255) | NO | - | - | Origin logistics terminal |
| `end_location` | VARCHAR(255) | NO | - | - | Destination logistics terminal |
| `estimated_distance_km` | DECIMAL(10,2) | NO | - | - | Distance in kilometers (`> 0`) |
| `estimated_time_minutes`| INT | NO | - | - | Expected transit minutes (`> 0`) |
| `toll_charges` | DECIMAL(10,2) | NO | - | 0.00 | Toll gate fees (INR) |
| `created_at` | DATETIME | NO | - | CURRENT_TIMESTAMP | Route registration date |

### 1.4 `vehicles`
| Column | Type | Nullable | Key | Default | Description |
|---|---|---|---|---|---|
| `id` | VARCHAR(36) | NO | PK | - | Vehicle UUID |
| `license_plate` | VARCHAR(20) | NO | UNI | - | Registration number (e.g. TN-01-AB-1001) |
| `model` | VARCHAR(100) | NO | - | - | Vehicle model (e.g. Tata Prima) |
| `vehicle_type` | ENUM | NO | - | 'LIGHT_TRUCK'| 'MINI_VAN', 'LIGHT_TRUCK', 'HEAVY_TRUCK', 'CONTAINER' |
| `capacity_kg` | DECIMAL(10,2) | NO | - | - | Max payload weight in kg (`> 0`) |
| `capacity_m3` | DECIMAL(10,2) | YES | - | NULL | Max volumetric payload in m³ |
| `status` | ENUM | NO | - | 'AVAILABLE' | 'AVAILABLE', 'IN_USE', 'MAINTENANCE', 'RETIRED' |
| `last_maintenance_date`| DATE | YES | - | NULL | Maintenance inspection date |

### 1.5 `drivers`
| Column | Type | Nullable | Key | Default | Description |
|---|---|---|---|---|---|
| `id` | VARCHAR(36) | NO | PK | - | Driver UUID |
| `name` | VARCHAR(100) | NO | - | - | Operator legal name |
| `license_number` | VARCHAR(50) | NO | UNI | - | Commercial Heavy Vehicle Driving License |
| `phone` | VARCHAR(20) | NO | - | - | Contact mobile number |
| `email` | VARCHAR(255) | NO | UNI | - | Driver notification email |
| `status` | ENUM | NO | - | 'ACTIVE' | 'ACTIVE', 'ON_DUTY', 'ON_LEAVE', 'SUSPENDED' |
| `hired_date` | DATE | NO | - | - | Date hired |
| `experience_years`| INT | YES | - | 1 | Years in commercial transport (`>= 0`) |

### 1.6 `driver_assignments`
| Column | Type | Nullable | Key | Default | Foreign Key Action |
|---|---|---|---|---|---|
| `id` | VARCHAR(36) | NO | PK | - | - |
| `driver_id` | VARCHAR(36) | NO | FK | - | `REFERENCES drivers(id) ON DELETE RESTRICT` |
| `vehicle_id` | VARCHAR(36) | NO | FK | - | `REFERENCES vehicles(id) ON DELETE RESTRICT` |
| `route_id` | VARCHAR(36) | YES | FK | NULL | `REFERENCES routes(id) ON DELETE SET NULL` |
| `assignment_date` | DATE | NO | - | - | Scheduled assignment date |
| `shift_start` | DATETIME | YES | - | NULL | Shift start time |
| `shift_end` | DATETIME | YES | - | NULL | Shift completion time |
| `status` | ENUM | NO | - | 'SCHEDULED' | 'SCHEDULED', 'ONGOING', 'COMPLETED', 'CANCELLED' |

### 1.7 `shipments`
| Column | Type | Nullable | Key | Default | Foreign Key Action |
|---|---|---|---|---|---|
| `id` | VARCHAR(36) | NO | PK | - | - |
| `tracking_number` | VARCHAR(50) | NO | UNI | - | Human-readable tracking identifier |
| `customer_id` | VARCHAR(36) | NO | FK | - | `REFERENCES customers(id) ON DELETE RESTRICT` |
| `origin_address` | TEXT | NO | - | - | Consignor pickup location |
| `destination_address`| TEXT | NO | - | - | Consignee destination location |
| `scheduled_pickup` | DATETIME | YES | - | NULL | Expected pickup date/time |
| `scheduled_delivery` | DATETIME | YES | - | NULL | Expected delivery date/time |
| `actual_delivery` | DATETIME | YES | - | NULL | Timestamp delivery completed |
| `status` | ENUM | NO | - | 'PENDING' | 'PENDING', 'BOOKED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED' |
| `weight` | DECIMAL(10,3) | NO | - | - | Cargo payload in kg (`> 0`) |
| `volume` | DECIMAL(10,3) | YES | - | NULL | Cargo volume in m³ |
| `cargo_type` | VARCHAR(100) | YES | - | 'General' | Goods categorization |
| `route_id` | VARCHAR(36) | YES | FK | NULL | `REFERENCES routes(id) ON DELETE SET NULL` |
| `driver_id` | VARCHAR(36) | YES | FK | NULL | `REFERENCES drivers(id) ON DELETE SET NULL` |
| `vehicle_id` | VARCHAR(36) | YES | FK | NULL | `REFERENCES vehicles(id) ON DELETE SET NULL` |

### 1.8 `tracking_events`
| Column | Type | Nullable | Key | Default | Foreign Key Action |
|---|---|---|---|---|---|
| `id` | VARCHAR(36) | NO | PK | - | - |
| `shipment_id` | VARCHAR(36) | NO | FK | - | `REFERENCES shipments(id) ON DELETE CASCADE` |
| `event_time` | DATETIME | NO | - | CURRENT_TIMESTAMP | Milestone checkpoint timestamp |
| `location` | VARCHAR(255) | NO | - | - | Hub or toll coordinate |
| `status` | VARCHAR(100) | NO | - | - | Milestone status description |
| `notes` | TEXT | YES | - | NULL | Checkpoint inspection observations |
| `created_by` | VARCHAR(50) | YES | - | 'SYSTEM' | Operator or trigger provenance |

### 1.9 `billing`
| Column | Type | Nullable | Key | Default | Description |
|---|---|---|---|---|---|
| `id` | VARCHAR(36) | NO | PK | - | Invoice UUID |
| `invoice_number` | VARCHAR(100) | NO | UNI | - | Unique tax invoice number |
| `shipment_id` | VARCHAR(36) | NO | FK | - | `REFERENCES shipments(id) ON DELETE RESTRICT` |
| `customer_id` | VARCHAR(36) | NO | FK | - | `REFERENCES customers(id) ON DELETE RESTRICT` |
| `amount` | DECIMAL(12,2) | NO | - | - | Base freight charge (INR) |
| `tax_amount` | DECIMAL(10,2) | NO | - | 0.00 | GST 18% charge (INR) |
| `total_amount` | DECIMAL(12,2) | NO | - | GENERATED | Stored generated column `(amount + tax_amount)` |
| `currency` | CHAR(3) | NO | - | 'INR' | Currency ISO code |
| `billing_date` | DATE | NO | - | - | Date invoice issued |
| `due_date` | DATE | YES | - | NULL | Payment terms deadline |
| `status` | ENUM | NO | - | 'UNPAID' | 'UNPAID', 'PARTIAL', 'PAID', 'OVERDUE', 'CANCELLED' |
| `payment_method` | ENUM | YES | - | NULL | 'NEFT', 'UPI', 'CREDIT_CARD', 'CASH', 'CHEQUE' |
| `paid_at` | DATETIME | YES | - | NULL | Timestamp of payment confirmation |

### 1.10 `inventory`
| Column | Type | Nullable | Key | Default | Description |
|---|---|---|---|---|---|
| `id` | VARCHAR(36) | NO | PK | - | Inventory item UUID |
| `item_code` | VARCHAR(50) | NO | UNI | - | SKU barcode / inventory tag |
| `item_name` | VARCHAR(255) | NO | - | - | Material name |
| `description` | TEXT | YES | - | NULL | Detailed specifications |
| `category` | VARCHAR(100) | YES | - | 'Packaging' | Material classification |
| `quantity` | INT | NO | - | 0 | Current stock on hand (`CHECK >= 0`) |
| `unit_of_measure`| VARCHAR(20) | YES | - | 'Units' | Packaging unit |
| `reorder_level` | INT | NO | - | 20 | Minimum threshold triggering replenishment |
| `unit_cost` | DECIMAL(10,2) | NO | - | 0.00 | Procurement cost per unit (INR) |
| `location` | VARCHAR(100) | NO | - | 'Chennai' | Warehouse bay / section |
