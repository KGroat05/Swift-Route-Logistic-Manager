# Normalization Analysis and Dependency Theory
## Swift Route Logistics Manager
**Course:** 21CSC205P Database Management Systems  
**Institution:** SRM Institute of Science and Technology  
**Student:** Krishang Gupta (RA2411026010810)  
**Supervisor:** Dr. Amit Kukker  

---

## 1. Pitfalls of Unnormalized Relational Designs

Consider an unnormalized universal logistics record represented as:

$$\text{UNIVERSAL\_LOGISTICS}(\underline{\text{ShipmentID}}, \text{CustName}, \text{CustEmail}, \text{CustAddress}, \text{Origin}, \text{Dest}, \text{CargoWeight}, \text{DriverLicense}, \text{DriverName}, \text{DriverPhone}, \text{VehiclePlate}, \text{VehicleCapacity}, \text{RouteName}, \text{DistanceKm}, \text{InvoiceNum}, \text{InvoiceAmount})$$

Storing this single monolithic relation suffers from four critical relational pitfalls:

1. **Redundancy**:
   Every time customer "Tata Electronics" places a shipment, their name, contact email, and address are redundantly duplicated across hundreds of rows.
2. **Insertion Anomaly**:
   A newly hired driver or recently acquired truck cannot be registered into the system until they are assigned to an actual shipment, because $\text{ShipmentID}$ is the primary key and cannot accept `NULL`.
3. **Deletion Anomaly**:
   If a customer cancels their only shipment and the record is purged, the company loses all record of the vehicle's maintenance history and the driver's contact details.
4. **Update Anomaly**:
   If a driver changes their contact mobile number, every historical and active shipment row mentioning that driver must be updated. If one row is missed, data inconsistency results.

---

## 2. Functional Dependencies (FDs)

Let the system schema be governed by the following canonical set of functional dependencies $F$:

1. **Customer Dependencies**:
   $$\text{customer\_id} \to \{\text{name}, \text{contact\_name}, \text{contact\_email}, \text{contact\_phone}, \text{address}, \text{city}, \text{state}, \text{postal\_code}\}$$
   $$\text{contact\_email} \to \{\text{customer\_id}, \text{name}, \dots\}$$

2. **Route Dependencies**:
   $$\text{route\_id} \to \{\text{name}, \text{start\_location}, \text{end\_location}, \text{estimated\_distance\_km}, \text{estimated\_time\_minutes}, \text{toll\_charges}\}$$

3. **Vehicle Dependencies**:
   $$\text{vehicle\_id} \to \{\text{license\_plate}, \text{model}, \text{vehicle\_type}, \text{capacity\_kg}, \text{capacity\_m3}, \text{status}, \text{last\_maintenance\_date}\}$$
   $$\text{license\_plate} \to \{\text{vehicle\_id}, \text{model}, \dots\}$$

4. **Driver Dependencies**:
   $$\text{driver\_id} \to \{\text{name}, \text{license\_number}, \text{phone}, \text{email}, \text{status}, \text{hired\_date}, \text{experience\_years}\}$$
   $$\text{license\_number} \to \{\text{driver\_id}, \dots\}$$
   $$\text{email} \to \{\text{driver\_id}, \dots\}$$

5. **Shipment Dependencies**:
   $$\text{shipment\_id} \to \{\text{tracking\_number}, \text{customer\_id}, \text{origin\_address}, \text{destination\_address}, \text{scheduled\_pickup}, \text{scheduled\_delivery}, \text{status}, \text{weight}, \text{volume}, \text{cargo\_type}, \text{route\_id}, \text{driver\_id}, \text{vehicle\_id}\}$$
   $$\text{tracking\_number} \to \{\text{shipment\_id}, \dots\}$$

6. **Billing Dependencies**:
   $$\text{billing\_id} \to \{\text{invoice\_number}, \text{shipment\_id}, \text{customer\_id}, \text{amount}, \text{tax\_amount}, \text{total\_amount}, \text{currency}, \text{billing\_date}, \text{status}, \text{payment\_method}\}$$
   $$\text{invoice\_number} \to \{\text{billing\_id}, \dots\}$$
   $$\text{shipment\_id} \to \{\text{billing\_id}, \text{amount}, \dots\}$$

7. **Inventory Dependencies**:
   $$\text{inventory\_id} \to \{\text{item\_code}, \text{item\_name}, \text{category}, \text{quantity}, \text{reorder\_level}, \text{unit\_cost}, \text{location}\}$$
   $$\text{item\_code} \to \{\text{inventory\_id}, \dots\}$$

---

## 3. Step-by-Step Normalization Process

### 3.1 First Normal Form (1NF)
* **Definition**: A relation $R$ is in 1NF if and only if all domain values are atomic (indivisible), and there are no repeating groups or multivalued arrays.
* **Applied in Swift Route**:
  - The universal table had multiple contact numbers and address blocks combined.
  - Separated composite addresses into atomic components (`address`, `city`, `state`, `postal_code`).
  - Tracking events are moved out of the shipment row into an independent relation (`tracking_events`), eliminating array-valued or repeating event columns.

### 3.2 Second Normal Form (2NF)
* **Definition**: A relation $R$ is in 2NF if it is in 1NF and no non-prime attribute is partially dependent on any proper subset of any candidate key.
* **Applied in Swift Route**:
  - In a composite dispatch relation with candidate key $\{\text{shipment\_id}, \text{vehicle\_id}\}$, attributes like $\text{vehicle\_capacity}$ depend solely on $\text{vehicle\_id}$ (a proper subset of the key).
  - Decomposed into distinct relations: `shipments` with key $\text{shipment\_id}$, and `vehicles` with key $\text{vehicle\_id}$. All non-prime attributes are fully functionally dependent on the primary key.

### 3.3 Third Normal Form (3NF)
* **Definition**: A relation $R$ is in 3NF if it is in 2NF and whenever a non-trivial functional dependency $X \to Y$ holds in $R$, either:
  1. $X$ is a superkey of $R$, or
  2. $Y$ is a prime attribute (part of a candidate key).
  *(Equivalently, no non-prime attribute is transitively dependent on the primary key).*
* **Applied in Swift Route**:
  - In the unnormalized shipment relation:
    $$\text{shipment\_id} \to \text{customer\_id} \quad \text{and} \quad \text{customer\_id} \to \text{customer\_city}$$
    $\text{customer\_city}$ is transitively dependent on $\text{shipment\_id}$ via $\text{customer\_id}$.
  - Extracted `customers` into its own relation with primary key `customer_id`. The foreign key `customer_id` remains in `shipments`. Transitive dependencies are completely eliminated.

### 3.4 Boyce-Codd Normal Form (BCNF)
* **Definition**: A relation $R$ is in BCNF if whenever a non-trivial functional dependency $X \to Y$ holds, $X$ is strictly a superkey.
* **Applied in Swift Route**:
  - In `users`, alternate candidate keys exist: `id`, `username`, and `email`. Each determinant is a candidate key.
  - In `vehicles`, alternate candidate keys exist: `id` and `license_plate`.
  - In `drivers`, alternate candidate keys exist: `id`, `license_number`, and `email`.
  - In `shipments`, alternate candidate keys exist: `id` and `tracking_number`.
  - In all cases, every determinant is a superkey. Therefore, the schema is in **BCNF**.

---

## 4. Higher Normal Forms: 4NF and 5NF

### 4.1 Fourth Normal Form (4NF)
* **Definition**: A relation $R$ is in 4NF if whenever a non-trivial Multi-Valued Dependency (MVD) $X \twoheadrightarrow Y$ holds in $R$, $X$ is a superkey.
* **Analysis**:
  Consider an operator schedule entity attempting to store:
  $$(\text{driver\_id}, \text{certified\_vehicle\_category}, \text{authorized\_state\_permit})$$
  Because a driver has multiple certified vehicle categories independently of their multiple state transit permits, the MVDs:
  $$\text{driver\_id} \twoheadrightarrow \text{certified\_vehicle\_category}$$
  $$\text{driver\_id} \twoheadrightarrow \text{authorized\_state\_permit}$$
  hold independently. Combining them creates Cartesian product redundancy.
* **Resolution**: Decomposed into binary relationships where each MVD is isolated, satisfying 4NF.

### 4.2 Fifth Normal Form (5NF / Project-Join Normal Form)
* **Definition**: A relation $R$ is in 5NF if it is in 4NF and every non-trivial Join Dependency (JD) $\bowtie [R_1, R_2, \dots, R_n]$ on $R$ is implied by the candidate keys of $R$.
* **Analysis of `driver_assignments`**:
  The scheduling relation involves a ternary relationship among three distinct real-world entities:
  - $\text{Driver} \;(D)$
  - $\text{Vehicle} \;(V)$
  - $\text{Route} \;(R)$
  If there is a cyclically constrained business rule where a driver can only drive specific vehicles, vehicles can only traverse specific routes (e.g. heavy multi-axles only on expressways), and drivers are certified on specific routes, the ternary relation $R(D, V, R)$ satisfies:
  $$\bowtie [\Pi_{D,V}(R), \Pi_{V,R}(R), \Pi_{D,R}(R)]$$
* **Justification**:
  In Swift Route Logistics Manager, the junction relation `driver_assignments` maintains the candidate key:
  $$\{\text{driver\_id}, \text{assignment\_date}, \text{shift\_start}\}$$
  along with explicit foreign keys to `drivers`, `vehicles`, and `routes`. No spurious tuples are generated upon natural join, guaranteeing losslessness and maintaining **5NF** consistency.
