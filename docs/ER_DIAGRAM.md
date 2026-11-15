# Entity-Relationship (ER) Model Documentation
## Swift Route Logistics Manager
**Course:** 21CSC205P Database Management Systems  
**Institution:** SRM Institute of Science and Technology  
**Student:** Krishang Gupta (RA2411026010810)  
**Supervisor:** Dr. Amit Kukker  

---

## 1. Conceptual ER Diagram (Chen & Crow's Foot Notation)

The system models a modern parcel and freight logistics dispatch infrastructure. The entities, attributes, and relationships are structured below:

```mermaid
erDiagram
    USERS {
        varchar(36) id PK
        varchar(50) username UK
        varchar(100) email UK
        varchar(255) password_hash
        varchar(100) full_name
        enum role "ADMIN, DISPATCHER, VIEWER"
        boolean is_active
        datetime created_at
    }

    CUSTOMERS {
        varchar(36) id PK
        varchar(255) name
        varchar(255) contact_name
        varchar(255) contact_email UK
        varchar(50) contact_phone
        text address
        varchar(100) city
        varchar(100) state
        varchar(20) postal_code
        datetime created_at
    }

    ROUTES {
        varchar(36) id PK
        varchar(100) name
        varchar(255) start_location
        varchar(255) end_location
        decimal estimated_distance_km
        int estimated_time_minutes
        decimal toll_charges
        datetime created_at
    }

    VEHICLES {
        varchar(36) id PK
        varchar(20) license_plate UK
        varchar(100) model
        enum vehicle_type "MINI_VAN, LIGHT_TRUCK, HEAVY_TRUCK, CONTAINER"
        decimal capacity_kg
        decimal capacity_m3
        enum status "AVAILABLE, IN_USE, MAINTENANCE, RETIRED"
        date last_maintenance_date
    }

    DRIVERS {
        varchar(36) id PK
        varchar(100) name
        varchar(50) license_number UK
        varchar(20) phone
        varchar(255) email UK
        enum status "ACTIVE, ON_DUTY, ON_LEAVE, SUSPENDED"
        date hired_date
        int experience_years
    }

    DRIVER_ASSIGNMENTS {
        varchar(36) id PK
        varchar(36) driver_id FK
        varchar(36) vehicle_id FK
        varchar(36) route_id FK
        date assignment_date
        datetime shift_start
        datetime shift_end
        enum status "SCHEDULED, ONGOING, COMPLETED, CANCELLED"
    }

    SHIPMENTS {
        varchar(36) id PK
        varchar(50) tracking_number UK
        varchar(36) customer_id FK
        text origin_address
        text destination_address
        datetime scheduled_pickup
        datetime scheduled_delivery
        datetime actual_delivery
        enum status "PENDING, BOOKED, IN_TRANSIT, OUT_FOR_DELIVERY, DELIVERED, CANCELLED"
        decimal weight
        decimal volume
        varchar(100) cargo_type
        varchar(36) route_id FK
        varchar(36) driver_id FK
        varchar(36) vehicle_id FK
        datetime created_at
    }

    TRACKING_EVENTS {
        varchar(36) id PK
        varchar(36) shipment_id FK
        datetime event_time
        varchar(255) location
        varchar(100) status
        text notes
        varchar(50) created_by
    }

    BILLING {
        varchar(36) id PK
        varchar(100) invoice_number UK
        varchar(36) shipment_id FK
        varchar(36) customer_id FK
        decimal amount
        decimal tax_amount
        decimal total_amount
        char(3) currency
        date billing_date
        date due_date
        enum status "UNPAID, PARTIAL, PAID, OVERDUE, CANCELLED"
        enum payment_method "NEFT, UPI, CREDIT_CARD, CASH, CHEQUE"
        datetime paid_at
    }

    INVENTORY {
        varchar(36) id PK
        varchar(50) item_code UK
        varchar(255) item_name
        text description
        varchar(100) category
        int quantity
        varchar(20) unit_of_measure
        int reorder_level
        decimal unit_cost
        varchar(100) location
        datetime last_updated
    }

    CUSTOMERS ||--o{ SHIPMENTS : "places (1:N)"
    CUSTOMERS ||--o{ BILLING : "receives (1:N)"
    ROUTES ||--o{ SHIPMENTS : "guides (1:N)"
    DRIVERS ||--o{ SHIPMENTS : "operates (1:N)"
    VEHICLES ||--o{ SHIPMENTS : "transports (1:N)"
    SHIPMENTS ||--|| BILLING : "generates (1:1)"
    SHIPMENTS ||--o{ TRACKING_EVENTS : "logs (1:N)"

    DRIVERS ||--o{ DRIVER_ASSIGNMENTS : "assigned_to (1:N)"
    VEHICLES ||--o{ DRIVER_ASSIGNMENTS : "allocated_to (1:N)"
    ROUTES ||--o{ DRIVER_ASSIGNMENTS : "designated_on (1:N)"
```

---

## 2. Cardinality and Participation Constraints

1. **Customer places Shipment (1:N)**:
   - A Customer can place zero, one, or many shipments over time.
   - Each Shipment must belong to exactly one Customer (`customer_id NOT NULL`, `ON DELETE RESTRICT`).

2. **Shipment assigned to Driver & Vehicle (N:1)**:
   - A Driver may transport multiple shipments sequentially over their tenure, but each active shipment has at most one primary driver.
   - A Vehicle may be utilized for multiple shipments sequentially, but each shipment is transported by at most one primary vehicle.

3. **Shipment follows Route (N:1)**:
   - A predefined Route (e.g. Chennai to Bengaluru Corridor) can serve hundreds of independent shipments over time.

4. **Shipment has Tracking Events (1:N)**:
   - Every shipment generates a chronological log of tracking events (`ON DELETE CASCADE`).
   - Trigger `trg_after_shipment_insert` automatically inserts the first event (`BOOKED` or `PENDING`).

5. **Shipment generates Billing Invoice (1:1)**:
   - Each shipment is linked to exactly one invoice. `total_amount` is calculated as a stored generated column (`amount + tax_amount`).

6. **Driver Assignments Junction (M:N with Schedule)**:
   - Resolves the complex ternary relationship between Drivers, Vehicles, and Routes over discrete scheduling intervals (`assignment_date`, `shift_start`, `shift_end`).
