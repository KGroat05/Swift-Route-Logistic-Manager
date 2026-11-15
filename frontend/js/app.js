/**
 * Swift Route Logistics Manager - Main Application Controller
 * Handles SPA navigation, data loading, modals, and user actions.
 */

// Global State
const appState = {
  currentView: "dashboard",
  customers: [],
  routes: [],
  drivers: [],
  vehicles: [],
  shipments: [],
  invoices: [],
  inventory: [],
  chartInstance: null
};

// Notification Toast Helper
function showToast(message, type = "info") {
  const container = document.getElementById("toast-container");
  if (!container) return;

  const toastEl = document.createElement("div");
  const bgClass = type === "success" ? "bg-success text-white" :
                  type === "error" ? "bg-danger text-white" :
                  type === "warning" ? "bg-warning text-dark" : "bg-primary text-white";

  toastEl.className = `toast align-items-center ${bgClass} border-0 show mb-2`;
  toastEl.setAttribute("role", "alert");
  toastEl.innerHTML = `
    <div class="d-flex">
      <div class="toast-body"><i class="bi bi-info-circle me-2"></i>${message}</div>
      <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
    </div>
  `;
  container.appendChild(toastEl);
  setTimeout(() => toastEl.remove(), 4000);
}

// Navigation View Switcher
function switchView(viewName) {
  appState.currentView = viewName;

  // Update navigation link active states
  document.querySelectorAll("#sidebar .nav-link").forEach(link => {
    link.classList.toggle("active", link.dataset.view === viewName);
  });

  // Toggle view containers
  document.querySelectorAll(".view-section").forEach(sec => {
    sec.classList.add("d-none");
  });
  const activeSec = document.getElementById(`view-${viewName}`);
  if (activeSec) {
    activeSec.classList.remove("d-none");
  }

  // Load view-specific data
  if (viewName === "dashboard") loadDashboard();
  else if (viewName === "shipments") loadShipments();
  else if (viewName === "customers") loadCustomers();
  else if (viewName === "fleet") loadFleet();
  else if (viewName === "routes") loadRoutes();
  else if (viewName === "billing") loadBilling();
  else if (viewName === "inventory") loadInventory();
  else if (viewName === "analytics") loadAnalytics();
  else if (viewName === "sqllab") initSqlLab();
}

// Update User UI Badge & Permissions
function updateAuthUI() {
  const user = window.auth.getCurrentUser();
  const badgeEl = document.getElementById("current-user-badge");
  const roleEl = document.getElementById("current-user-role");

  if (user) {
    if (badgeEl) badgeEl.textContent = user.full_name;
    if (roleEl) {
      roleEl.textContent = user.role;
      roleEl.className = `badge ${user.role === 'ADMIN' ? 'bg-danger' : user.role === 'DISPATCHER' ? 'bg-primary' : 'bg-secondary'}`;
    }

    // Role-based button visibility
    const canWrite = window.auth.isDispatcher();
    const isAdmin = window.auth.isAdmin();

    document.querySelectorAll(".require-dispatcher").forEach(el => {
      el.style.display = canWrite ? "" : "none";
    });
    document.querySelectorAll(".require-admin").forEach(el => {
      el.style.display = isAdmin ? "" : "none";
    });
  }
}

// ---------------------------------------------------------------------
// 1. DASHBOARD CONTROLLER
// ---------------------------------------------------------------------
async function loadDashboard() {
  try {
    const kpis = await window.api.get("/api/v1/analytics/dashboard");

    document.getElementById("kpi-active-shipments").textContent = kpis.active_shipments;
    document.getElementById("kpi-delivered-shipments").textContent = kpis.delivered_shipments;
    document.getElementById("kpi-total-revenue").textContent = `₹${parseFloat(kpis.total_revenue_inr).toLocaleString('en-IN')}`;
    document.getElementById("kpi-available-vehicles").textContent = kpis.available_vehicles;
    document.getElementById("kpi-active-drivers").textContent = kpis.active_drivers;
    document.getElementById("kpi-low-stock").textContent = kpis.low_stock_items_count;

    // Load Status Distribution Chart
    const statusData = await window.api.get("/api/v1/analytics/shipment-status-distribution");
    renderDashboardChart(statusData);

    // Load Recent Shipments Table
    const recent = await window.api.get("/api/v1/shipments", { limit: 5 });
    const tbody = document.getElementById("recent-shipments-tbody");
    if (tbody) {
      tbody.innerHTML = recent.map(s => `
        <tr>
          <td><span class="fw-bold">${s.tracking_number}</span></td>
          <td>${s.customer ? s.customer.name : 'Unknown'}</td>
          <td>${s.route ? s.route.name : 'Direct Transit'}</td>
          <td>${s.weight} kg</td>
          <td><span class="badge badge-status badge-${s.status.toLowerCase()}">${s.status.replace('_', ' ')}</span></td>
          <td>
            <button class="btn btn-sm btn-outline-primary" onclick="viewShipmentTimeline('${s.id}')">
              <i class="bi bi-clock-history"></i>
            </button>
          </td>
        </tr>
      `).join("");
    }
  } catch (err) {
    showToast(`Failed to load dashboard: ${err.message}`, "error");
  }
}

function renderDashboardChart(statusData) {
  const ctx = document.getElementById("shipmentStatusChart");
  if (!ctx) return;

  const labels = statusData.map(d => d.status.replace('_', ' '));
  const counts = statusData.map(d => d.count);

  if (appState.chartInstance) {
    appState.chartInstance.destroy();
  }

  appState.chartInstance = new Chart(ctx, {
    type: "doughnut",
    data: {
      labels: labels,
      datasets: [{
        data: counts,
        backgroundColor: [
          "#94a3b8", // PENDING
          "#38bdf8", // BOOKED
          "#2563eb", // IN_TRANSIT
          "#f59e0b", // OUT_FOR_DELIVERY
          "#10b981", // DELIVERED
          "#ef4444"  // CANCELLED
        ],
        borderWidth: 2,
        borderColor: "#ffffff"
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: "bottom" }
      }
    }
  });
}

// ---------------------------------------------------------------------
// 2. SHIPMENTS CONTROLLER
// ---------------------------------------------------------------------
async function loadShipments() {
  try {
    const statusFilter = document.getElementById("filter-shipment-status")?.value || "";
    const searchFilter = document.getElementById("search-shipments")?.value || "";

    const params = {};
    if (statusFilter) params.status = statusFilter;
    if (searchFilter) params.search = searchFilter;

    const shipments = await window.api.get("/api/v1/shipments", params);
    appState.shipments = shipments;

    const tbody = document.getElementById("shipments-table-body");
    if (!tbody) return;

    if (shipments.length === 0) {
      tbody.innerHTML = `<tr><td colspan="9" class="text-center py-4 text-muted">No shipments found matching filters.</td></tr>`;
      return;
    }

    tbody.innerHTML = shipments.map(s => {
      const driverName = s.driver ? s.driver.name : '<span class="text-muted">Unassigned</span>';
      const vehiclePlate = s.vehicle ? s.vehicle.license_plate : '<span class="text-muted">Unassigned</span>';
      const routeName = s.route ? s.route.name : '<span class="text-muted">Direct</span>';
      const canEdit = window.auth.isDispatcher() && s.status !== 'DELIVERED' && s.status !== 'CANCELLED';

      return `
        <tr>
          <td><span class="fw-bold text-primary">${s.tracking_number}</span></td>
          <td>${s.customer ? s.customer.name : 'N/A'}</td>
          <td><small class="text-muted">${routeName}</small></td>
          <td>${s.cargo_type || 'General'}</td>
          <td>${s.weight} kg</td>
          <td><small>${vehiclePlate}</small></td>
          <td><small>${driverName}</small></td>
          <td><span class="badge badge-status badge-${s.status.toLowerCase()}">${s.status.replace('_', ' ')}</span></td>
          <td>
            <div class="btn-group btn-group-sm">
              <button class="btn btn-outline-info" title="Tracking Timeline" onclick="viewShipmentTimeline('${s.id}')">
                <i class="bi bi-geo-alt"></i>
              </button>
              ${canEdit ? `
                <button class="btn btn-outline-primary" title="Update Status" onclick="openStatusModal('${s.id}', '${s.status}')">
                  <i class="bi bi-arrow-repeat"></i>
                </button>
                <button class="btn btn-outline-danger" title="Cancel Shipment" onclick="cancelShipmentAction('${s.id}')">
                  <i class="bi bi-x-circle"></i>
                </button>
              ` : ''}
            </div>
          </td>
        </tr>
      `;
    }).join("");
  } catch (err) {
    showToast(`Error loading shipments: ${err.message}`, "error");
  }
}

// Open Booking Modal & Populate Dropdowns
async function openBookingModal() {
  try {
    const [customers, routes, vehicles, drivers] = await Promise.all([
      window.api.get("/api/v1/customers"),
      window.api.get("/api/v1/routes"),
      window.api.get("/api/v1/vehicles/available"),
      window.api.get("/api/v1/drivers/available")
    ]);

    // Populate Customers
    const custSelect = document.getElementById("book-customer");
    custSelect.innerHTML = `<option value="">Select Customer...</option>` +
      customers.map(c => `<option value="${c.id}">${c.name} (${c.city})</option>`).join("");

    // Populate Routes
    const routeSelect = document.getElementById("book-route");
    routeSelect.innerHTML = `<option value="">Select Predefined Route...</option>` +
      routes.map(r => `<option value="${r.id}" data-distance="${r.estimated_distance_km}">${r.name} (${r.estimated_distance_km} km)</option>`).join("");

    // Populate Vehicles
    const vehSelect = document.getElementById("book-vehicle");
    vehSelect.innerHTML = `<option value="">Select Available Vehicle...</option>` +
      vehicles.map(v => `<option value="${v.id}" data-cap="${v.capacity_kg}">${v.license_plate} - ${v.model} (Max: ${v.capacity_kg} kg)</option>`).join("");

    // Populate Drivers
    const drvSelect = document.getElementById("book-driver");
    drvSelect.innerHTML = `<option value="">Select Available Driver...</option>` +
      drivers.map(d => `<option value="${d.id}">${d.name} (${d.experience_years} yrs exp)</option>`).join("");

    const modal = new bootstrap.Modal(document.getElementById("modal-book-shipment"));
    modal.show();
  } catch (err) {
    showToast(`Failed to initialize booking dialog: ${err.message}`, "error");
  }
}

// Automated Freight Charge Calculation (replicates fn_calculate_freight_charge)
function updateFreightEstimation() {
  const weight = parseFloat(document.getElementById("book-weight").value) || 0;
  const routeSelect = document.getElementById("book-route");
  const selectedOpt = routeSelect.options[routeSelect.selectedIndex];
  const distance = selectedOpt ? parseFloat(selectedOpt.dataset.distance) || 0 : 0;

  if (weight > 0 && distance > 0) {
    const base = 500.0;
    const weightCost = weight * 2.50;
    const distCost = distance * 6.00;
    const est = base + weightCost + distCost;
    document.getElementById("book-billing-amount").value = est.toFixed(2);
  }
}

// Submit Shipment Booking
async function submitShipmentBooking(e) {
  e.preventDefault();
  const weight = parseFloat(document.getElementById("book-weight").value);
  const vehSelect = document.getElementById("book-vehicle");
  const selectedVehOpt = vehSelect.options[vehSelect.selectedIndex];

  // Client-side capacity pre-check
  if (selectedVehOpt && selectedVehOpt.value) {
    const maxCap = parseFloat(selectedVehOpt.dataset.cap);
    if (weight > maxCap) {
      alert(`Validation Warning: Cargo weight (${weight} kg) exceeds vehicle payload capacity (${maxCap} kg). Please select a higher-capacity truck.`);
      return;
    }
  }

  const payload = {
    customer_id: document.getElementById("book-customer").value,
    origin_address: document.getElementById("book-origin").value,
    destination_address: document.getElementById("book-destination").value,
    weight: weight,
    volume: parseFloat(document.getElementById("book-volume").value) || null,
    cargo_type: document.getElementById("book-cargo-type").value,
    route_id: document.getElementById("book-route").value || null,
    vehicle_id: document.getElementById("book-vehicle").value || null,
    driver_id: document.getElementById("book-driver").value || null,
    billing_amount: parseFloat(document.getElementById("book-billing-amount").value) || 0,
    payment_method: document.getElementById("book-payment-method").value || null
  };

  try {
    const res = await window.api.post("/api/v1/shipments", payload);
    showToast(`Shipment booked successfully! Tracking #: ${res.tracking_number}`, "success");
    bootstrap.Modal.getInstance(document.getElementById("modal-book-shipment")).hide();
    loadShipments();
  } catch (err) {
    showToast(`Booking failed: ${err.message}`, "error");
  }
}

// Open Status Transition Modal
function openStatusModal(shipmentId, currentStatus) {
  document.getElementById("status-shipment-id").value = shipmentId;
  document.getElementById("status-current-display").textContent = currentStatus;
  document.getElementById("status-new-select").value = currentStatus;
  document.getElementById("status-location").value = "";
  document.getElementById("status-notes").value = "";

  const modal = new bootstrap.Modal(document.getElementById("modal-update-status"));
  modal.show();
}

async function submitStatusUpdate(e) {
  e.preventDefault();
  const shipmentId = document.getElementById("status-shipment-id").value;
  const payload = {
    status: document.getElementById("status-new-select").value,
    location: document.getElementById("status-location").value,
    notes: document.getElementById("status-notes").value
  };

  try {
    await window.api.post(`/api/v1/shipments/${shipmentId}/status`, payload);
    showToast("Shipment status updated and tracking event recorded.", "success");
    bootstrap.Modal.getInstance(document.getElementById("modal-update-status")).hide();
    loadShipments();
  } catch (err) {
    showToast(`Status update failed: ${err.message}`, "error");
  }
}

async function cancelShipmentAction(shipmentId) {
  if (!confirm("Are you sure you want to cancel this shipment? Allocated vehicles and drivers will be automatically released back to the fleet.")) {
    return;
  }
  try {
    await window.api.post(`/api/v1/shipments/${shipmentId}/cancel`);
    showToast("Shipment cancelled and fleet resources released.", "success");
    loadShipments();
  } catch (err) {
    showToast(`Cancellation failed: ${err.message}`, "error");
  }
}

// ---------------------------------------------------------------------
// 3. TRACKING TIMELINE
// ---------------------------------------------------------------------
async function viewShipmentTimeline(shipmentId) {
  try {
    const shipment = await window.api.get(`/api/v1/shipments/${shipmentId}`);
    renderTimelineModal(shipment);
  } catch (err) {
    showToast(`Failed to load timeline: ${err.message}`, "error");
  }
}

async function searchTrackingNumber(e) {
  if (e) e.preventDefault();
  const input = document.getElementById("public-tracking-input");
  const trackNum = input.value.trim();
  if (!trackNum) return;

  try {
    const shipment = await window.api.get(`/api/v1/shipments/track/${trackNum}`);
    renderPublicTracking(shipment);
  } catch (err) {
    showToast(`Tracking lookup failed: ${err.message}`, "error");
    document.getElementById("tracking-result-container").innerHTML = `
      <div class="alert alert-danger">No active shipment found with tracking code <strong>${trackNum}</strong>.</div>
    `;
  }
}

function renderPublicTracking(s) {
  const container = document.getElementById("tracking-result-container");
  if (!container) return;

  const eventsHtml = s.tracking_events.map(ev => `
    <div class="timeline-item">
      <div class="timeline-dot completed"></div>
      <div class="timeline-content">
        <div class="d-flex justify-content-between align-items-center mb-1">
          <span class="badge badge-status badge-${ev.status.toLowerCase()}">${ev.status.replace('_', ' ')}</span>
          <small class="text-muted"><i class="bi bi-clock me-1"></i>${new Date(ev.event_time).toLocaleString()}</small>
        </div>
        <div class="fw-semibold text-dark"><i class="bi bi-geo-alt-fill text-danger me-1"></i>${ev.location}</div>
        <p class="mb-0 text-muted small mt-1">${ev.notes || 'Checkpoint recorded.'}</p>
      </div>
    </div>
  `).join("");

  container.innerHTML = `
    <div class="card content-card mb-4">
      <div class="card-header bg-primary text-white d-flex justify-content-between align-items-center">
        <span><i class="bi bi-box-seam me-2"></i>Shipment ${s.tracking_number}</span>
        <span class="badge bg-light text-dark">${s.status.replace('_', ' ')}</span>
      </div>
      <div class="card-body">
        <div class="row mb-3">
          <div class="col-md-6">
            <small class="text-muted d-block">Origin</small>
            <strong>${s.origin_address}</strong>
          </div>
          <div class="col-md-6">
            <small class="text-muted d-block">Destination</small>
            <strong>${s.destination_address}</strong>
          </div>
        </div>
        <div class="row mb-3">
          <div class="col-md-3"><small class="text-muted d-block">Cargo</small><strong>${s.cargo_type}</strong></div>
          <div class="col-md-3"><small class="text-muted d-block">Weight</small><strong>${s.weight} kg</strong></div>
          <div class="col-md-3"><small class="text-muted d-block">Assigned Vehicle</small><strong>${s.vehicle ? s.vehicle.license_plate : 'N/A'}</strong></div>
          <div class="col-md-3"><small class="text-muted d-block">Driver</small><strong>${s.driver ? s.driver.name : 'N/A'}</strong></div>
        </div>
        <h6 class="border-top pt-3 mb-3 fw-bold"><i class="bi bi-signpost-split me-2"></i>Milestone Timeline</h6>
        <div class="timeline">${eventsHtml}</div>
      </div>
    </div>
  `;
}

function renderTimelineModal(s) {
  document.getElementById("modal-timeline-title").textContent = `Timeline: ${s.tracking_number}`;
  const container = document.getElementById("modal-timeline-body");

  const eventsHtml = (s.tracking_events || []).map(ev => `
    <div class="timeline-item">
      <div class="timeline-dot completed"></div>
      <div class="timeline-content">
        <div class="d-flex justify-content-between align-items-center mb-1">
          <span class="badge badge-status badge-${ev.status.toLowerCase()}">${ev.status.replace('_', ' ')}</span>
          <small class="text-muted"><i class="bi bi-clock me-1"></i>${new Date(ev.event_time).toLocaleString()}</small>
        </div>
        <div class="fw-semibold text-dark"><i class="bi bi-geo-alt-fill text-danger me-1"></i>${ev.location}</div>
        <p class="mb-0 text-muted small mt-1">${ev.notes || 'Status logged.'}</p>
        <small class="text-muted" style="font-size: 0.75rem;">Source: ${ev.created_by}</small>
      </div>
    </div>
  `).join("");

  container.innerHTML = `
    <div class="mb-3 p-2 bg-light rounded">
      <div><strong>Sender:</strong> ${s.customer ? s.customer.name : 'N/A'}</div>
      <div><strong>Current Status:</strong> <span class="badge badge-status badge-${s.status.toLowerCase()}">${s.status.replace('_', ' ')}</span></div>
      <div><strong>Route:</strong> ${s.route ? s.route.name : 'Direct'}</div>
    </div>
    <div class="timeline">${eventsHtml || '<p class="text-muted">No timeline events recorded yet.</p>'}</div>
  `;

  const modal = new bootstrap.Modal(document.getElementById("modal-shipment-timeline"));
  modal.show();
}

// ---------------------------------------------------------------------
// 4. CUSTOMERS CONTROLLER
// ---------------------------------------------------------------------
async function loadCustomers() {
  try {
    const search = document.getElementById("search-customers")?.value || "";
    const customers = await window.api.get("/api/v1/customers", { search });
    appState.customers = customers;

    const tbody = document.getElementById("customers-table-body");
    if (!tbody) return;

    tbody.innerHTML = customers.map(c => `
      <tr>
        <td><strong>${c.name}</strong></td>
        <td>${c.contact_name || '-'}</td>
        <td>${c.contact_email}</td>
        <td>${c.contact_phone}</td>
        <td>${c.city}, ${c.state}</td>
        <td>
          ${window.auth.isDispatcher() ? `
            <button class="btn btn-sm btn-outline-primary me-1" onclick="openEditCustomerModal('${c.id}')"><i class="bi bi-pencil"></i></button>
          ` : ''}
          ${window.auth.isAdmin() ? `
            <button class="btn btn-sm btn-outline-danger" onclick="deleteCustomerAction('${c.id}')"><i class="bi bi-trash"></i></button>
          ` : ''}
        </td>
      </tr>
    `).join("");
  } catch (err) {
    showToast(`Error loading customers: ${err.message}`, "error");
  }
}

function openCreateCustomerModal() {
  document.getElementById("cust-modal-title").textContent = "Register New Customer";
  document.getElementById("cust-id").value = "";
  document.getElementById("cust-name").value = "";
  document.getElementById("cust-contact-name").value = "";
  document.getElementById("cust-email").value = "";
  document.getElementById("cust-phone").value = "";
  document.getElementById("cust-address").value = "";
  document.getElementById("cust-city").value = "Chennai";
  document.getElementById("cust-state").value = "Tamil Nadu";
  document.getElementById("cust-postal").value = "600001";

  const modal = new bootstrap.Modal(document.getElementById("modal-customer"));
  modal.show();
}

function openEditCustomerModal(id) {
  const c = appState.customers.find(item => item.id === id);
  if (!c) return;

  document.getElementById("cust-modal-title").textContent = "Edit Customer";
  document.getElementById("cust-id").value = c.id;
  document.getElementById("cust-name").value = c.name;
  document.getElementById("cust-contact-name").value = c.contact_name || "";
  document.getElementById("cust-email").value = c.contact_email;
  document.getElementById("cust-phone").value = c.contact_phone;
  document.getElementById("cust-address").value = c.address;
  document.getElementById("cust-city").value = c.city;
  document.getElementById("cust-state").value = c.state;
  document.getElementById("cust-postal").value = c.postal_code;

  const modal = new bootstrap.Modal(document.getElementById("modal-customer"));
  modal.show();
}

async function submitCustomerForm(e) {
  e.preventDefault();
  const id = document.getElementById("cust-id").value;
  const payload = {
    name: document.getElementById("cust-name").value,
    contact_name: document.getElementById("cust-contact-name").value,
    contact_email: document.getElementById("cust-email").value,
    contact_phone: document.getElementById("cust-phone").value,
    address: document.getElementById("cust-address").value,
    city: document.getElementById("cust-city").value,
    state: document.getElementById("cust-state").value,
    postal_code: document.getElementById("cust-postal").value
  };

  try {
    if (id) {
      await window.api.put(`/api/v1/customers/${id}`, payload);
      showToast("Customer updated successfully.", "success");
    } else {
      await window.api.post("/api/v1/customers", payload);
      showToast("Customer registered successfully.", "success");
    }
    bootstrap.Modal.getInstance(document.getElementById("modal-customer")).hide();
    loadCustomers();
  } catch (err) {
    showToast(`Save failed: ${err.message}`, "error");
  }
}

async function deleteCustomerAction(id) {
  if (!confirm("Are you sure you want to delete this customer?")) return;
  try {
    await window.api.delete(`/api/v1/customers/${id}`);
    showToast("Customer deleted.", "success");
    loadCustomers();
  } catch (err) {
    showToast(`Delete failed: ${err.message}`, "error");
  }
}

// ---------------------------------------------------------------------
// 5. FLEET & DRIVERS CONTROLLER
// ---------------------------------------------------------------------
async function loadFleet() {
  try {
    const [vehicles, drivers] = await Promise.all([
      window.api.get("/api/v1/vehicles"),
      window.api.get("/api/v1/drivers")
    ]);
    appState.vehicles = vehicles;
    appState.drivers = drivers;

    // Render Vehicles
    const vTbody = document.getElementById("vehicles-table-body");
    if (vTbody) {
      vTbody.innerHTML = vehicles.map(v => `
        <tr>
          <td><strong>${v.license_plate}</strong></td>
          <td>${v.model}</td>
          <td><span class="badge bg-secondary">${v.vehicle_type}</span></td>
          <td>${v.capacity_kg} kg</td>
          <td><span class="badge badge-status badge-${v.status.toLowerCase()}">${v.status}</span></td>
          <td>${v.last_maintenance_date || 'N/A'}</td>
        </tr>
      `).join("");
    }

    // Render Drivers
    const dTbody = document.getElementById("drivers-table-body");
    if (dTbody) {
      dTbody.innerHTML = drivers.map(d => `
        <tr>
          <td><strong>${d.name}</strong></td>
          <td><code>${d.license_number}</code></td>
          <td>${d.phone}</td>
          <td><span class="badge badge-status badge-${d.status.toLowerCase()}">${d.status}</span></td>
          <td>${d.experience_years} yrs</td>
          <td>${d.hired_date}</td>
        </tr>
      `).join("");
    }
  } catch (err) {
    showToast(`Error loading fleet data: ${err.message}`, "error");
  }
}

// Driver Payouts Cursor Calculation
async function runDriverPayoutsCalculation() {
  try {
    const res = await window.api.get("/api/v1/drivers/payouts/calculate");
    const container = document.getElementById("payout-results-body");
    container.innerHTML = `
      <div class="alert alert-info">
        <i class="bi bi-cpu me-2"></i><strong>MySQL Cursor Execution:</strong> 
        Iterated through ${res.total_drivers_processed} driver records in <code>sp_calculate_driver_payout</code> temporary table.
      </div>
      <div class="table-responsive">
        <table class="table table-sm table-striped">
          <thead>
            <tr>
              <th>Driver</th>
              <th>Trips Delivered</th>
              <th>Distance (km)</th>
              <th>Base Salary</th>
              <th>Trip Bonus</th>
              <th>Incentive</th>
              <th>Total Payout</th>
            </tr>
          </thead>
          <tbody>
            ${res.payout_breakdown.map(p => `
              <tr>
                <td><strong>${p.driver_name}</strong></td>
                <td><span class="badge bg-success">${p.completed_deliveries}</span></td>
                <td>${p.total_distance_km} km</td>
                <td>₹${p.base_salary.toLocaleString('en-IN')}</td>
                <td>₹${p.trip_bonus.toLocaleString('en-IN')}</td>
                <td>₹${p.distance_incentive.toLocaleString('en-IN')}</td>
                <td><strong class="text-primary">₹${p.net_payout_inr.toLocaleString('en-IN')}</strong></td>
              </tr>
            `).join("")}
          </tbody>
        </table>
      </div>
    `;
    const modal = new bootstrap.Modal(document.getElementById("modal-driver-payouts"));
    modal.show();
  } catch (err) {
    showToast(`Payout calculation failed: ${err.message}`, "error");
  }
}

// ---------------------------------------------------------------------
// 6. ROUTES CONTROLLER
// ---------------------------------------------------------------------
async function loadRoutes() {
  try {
    const routes = await window.api.get("/api/v1/routes");
    appState.routes = routes;

    const tbody = document.getElementById("routes-table-body");
    if (!tbody) return;

    tbody.innerHTML = routes.map(r => `
      <tr>
        <td><strong>${r.name}</strong></td>
        <td>${r.start_location}</td>
        <td>${r.end_location}</td>
        <td><span class="badge bg-light text-dark border">${r.estimated_distance_km} km</span></td>
        <td>${Math.floor(r.estimated_time_minutes / 60)}h ${r.estimated_time_minutes % 60}m</td>
        <td>₹${parseFloat(r.toll_charges).toFixed(2)}</td>
      </tr>
    `).join("");
  } catch (err) {
    showToast(`Error loading routes: ${err.message}`, "error");
  }
}

// ---------------------------------------------------------------------
// 7. BILLING & INVOICES CONTROLLER
// ---------------------------------------------------------------------
async function loadBilling() {
  try {
    const [invoices, finSummary] = await Promise.all([
      window.api.get("/api/v1/billing"),
      window.api.get("/api/v1/analytics/views/financial-summary")
    ]);
    appState.invoices = invoices;

    // Update Financial Metrics
    document.getElementById("fin-gross-billed").textContent = `₹${parseFloat(finSummary.gross_billed_amount || 0).toLocaleString('en-IN')}`;
    document.getElementById("fin-collected").textContent = `₹${parseFloat(finSummary.collected_revenue || 0).toLocaleString('en-IN')}`;
    document.getElementById("fin-receivables").textContent = `₹${parseFloat((finSummary.pending_receivables || 0) + (finSummary.overdue_receivables || 0)).toLocaleString('en-IN')}`;
    document.getElementById("fin-efficiency").textContent = `${finSummary.collection_efficiency_pct || 0}%`;

    const tbody = document.getElementById("billing-table-body");
    if (!tbody) return;

    tbody.innerHTML = invoices.map(b => `
      <tr>
        <td><strong>${b.invoice_number}</strong></td>
        <td>₹${parseFloat(b.amount).toLocaleString('en-IN')}</td>
        <td>₹${parseFloat(b.tax_amount).toLocaleString('en-IN')}</td>
        <td><strong>₹${parseFloat(b.total_amount || (parseFloat(b.amount) + parseFloat(b.tax_amount))).toLocaleString('en-IN')}</strong></td>
        <td>${b.billing_date}</td>
        <td>${b.due_date || '-'}</td>
        <td><span class="badge badge-status badge-${b.status.toLowerCase()}">${b.status}</span></td>
        <td>${b.payment_method || '-'}</td>
        <td>
          ${b.status !== 'PAID' && window.auth.isDispatcher() ? `
            <button class="btn btn-sm btn-outline-success" onclick="markInvoicePaidPrompt('${b.id}')">
              <i class="bi bi-check-circle me-1"></i>Pay
            </button>
          ` : ''}
        </td>
      </tr>
    `).join("");
  } catch (err) {
    showToast(`Error loading invoices: ${err.message}`, "error");
  }
}

async function markInvoicePaidPrompt(invoiceId) {
  const method = prompt("Select payment method (UPI, NEFT, CREDIT_CARD, CASH):", "UPI");
  if (!method) return;

  try {
    await window.api.put(`/api/v1/billing/${invoiceId}/payment`, {
      status: "PAID",
      payment_method: method.toUpperCase()
    });
    showToast("Invoice marked as PAID. Auto-timestamp trigger executed.", "success");
    loadBilling();
  } catch (err) {
    showToast(`Payment update failed: ${err.message}`, "error");
  }
}

// ---------------------------------------------------------------------
// 8. WAREHOUSE INVENTORY CONTROLLER
// ---------------------------------------------------------------------
async function loadInventory() {
  try {
    const items = await window.api.get("/api/v1/inventory");
    appState.inventory = items;

    const tbody = document.getElementById("inventory-table-body");
    if (!tbody) return;

    tbody.innerHTML = items.map(i => {
      const isLow = i.quantity <= i.reorder_level;
      return `
        <tr class="${isLow ? 'table-warning' : ''}">
          <td><code>${i.item_code}</code></td>
          <td><strong>${i.item_name}</strong></td>
          <td>${i.category}</td>
          <td>
            <strong class="${isLow ? 'text-danger' : 'text-success'}">${i.quantity} ${i.unit_of_measure}</strong>
            ${isLow ? '<span class="badge bg-danger ms-2">LOW STOCK</span>' : ''}
          </td>
          <td>${i.reorder_level}</td>
          <td>₹${parseFloat(i.unit_cost).toFixed(2)}</td>
          <td><small class="text-muted">${i.location}</small></td>
          <td>
            ${window.auth.isDispatcher() ? `
              <button class="btn btn-sm btn-outline-primary" onclick="adjustInventoryStock('${i.id}', ${i.quantity})">
                <i class="bi bi-plus-slash-minus"></i>
              </button>
            ` : ''}
          </td>
        </tr>
      `;
    }).join("");
  } catch (err) {
    showToast(`Error loading inventory: ${err.message}`, "error");
  }
}

async function adjustInventoryStock(itemId, currentQty) {
  const qtyStr = prompt("Enter new inventory quantity (must be >= 0):", currentQty);
  if (qtyStr === null) return;
  const newQty = parseInt(qtyStr, 10);
  if (isNaN(newQty) || newQty < 0) {
    alert("Quantity must be a non-negative integer.");
    return;
  }

  try {
    await window.api.put(`/api/v1/inventory/${itemId}`, { quantity: newQty });
    showToast("Inventory quantity updated.", "success");
    loadInventory();
  } catch (err) {
    showToast(`Inventory update failed: ${err.message}`, "error");
  }
}

async function executeInventoryRestockAudit() {
  try {
    const res = await window.api.post("/api/v1/inventory/audit-restock");
    const summary = typeof res.audit_summary === "string" ? JSON.parse(res.audit_summary) : res.audit_summary;
    alert(`Inventory Restock Audit Completed!\n\nProcedure: ${res.procedure_name}\nDepleted Items Count: ${summary.depleted_items_count}\nEstimated Procurement Cost: ₹${summary.total_procurement_cost_inr.toLocaleString('en-IN')}`);
    loadInventory();
  } catch (err) {
    showToast(`Restock audit failed: ${err.message}`, "error");
  }
}

// ---------------------------------------------------------------------
// 9. ANALYTICS & VIEWS CONTROLLER
// ---------------------------------------------------------------------
async function loadAnalytics() {
  try {
    const [driverPerf, routePerf] = await Promise.all([
      window.api.get("/api/v1/analytics/views/driver-performance"),
      window.api.get("/api/v1/analytics/views/route-analytics")
    ]);

    // Render Driver Performance View
    const drvBody = document.getElementById("analytics-driver-body");
    if (drvBody) {
      drvBody.innerHTML = driverPerf.map(d => `
        <tr>
          <td><strong>${d.driver_name}</strong></td>
          <td>${d.total_assigned_shipments}</td>
          <td><span class="badge bg-success">${d.delivered_shipments}</span></td>
          <td>${d.active_shipments}</td>
          <td>${d.total_distance_km_delivered} km</td>
          <td>${d.avg_payload_kg} kg</td>
          <td><strong>${d.delivery_success_rate_pct}%</strong></td>
        </tr>
      `).join("");
    }

    // Render Route Performance View
    const rtBody = document.getElementById("analytics-route-body");
    if (rtBody) {
      rtBody.innerHTML = routePerf.map(r => `
        <tr>
          <td><strong>${r.route_name}</strong></td>
          <td>${r.estimated_distance_km} km</td>
          <td>${r.total_shipments_routed}</td>
          <td>${r.total_cargo_weight_kg} kg</td>
          <td>₹${parseFloat(r.total_revenue_generated).toLocaleString('en-IN')}</td>
          <td><strong>₹${r.revenue_per_km_inr}</strong></td>
        </tr>
      `).join("");
    }
  } catch (err) {
    showToast(`Error loading analytics: ${err.message}`, "error");
  }
}

// ---------------------------------------------------------------------
// 10. INTERACTIVE SQL LAB & CONCURRENCY SIMULATOR
// ---------------------------------------------------------------------
let preloadedQueries = [];

async function initSqlLab() {
  try {
    if (preloadedQueries.length === 0) {
      preloadedQueries = await window.api.get("/api/v1/sql/preloaded-queries");
      const selector = document.getElementById("sql-query-select");
      if (selector) {
        selector.innerHTML = `<option value="">Choose Pre-crafted DBMS Query...</option>` +
          preloadedQueries.map((q, idx) => `<option value="${idx}">${q.title}</option>`).join("");
      }
    }
  } catch (err) {
    showToast(`Failed to load SQL queries: ${err.message}`, "error");
  }
}

function selectPreloadedQuery(idx) {
  if (idx === "") return;
  const q = preloadedQueries[parseInt(idx, 10)];
  if (q) {
    document.getElementById("sql-editor-textarea").value = q.sql;
    document.getElementById("sql-query-description").textContent = q.description;
  }
}

async function runSqlQuery() {
  const query = document.getElementById("sql-editor-textarea").value.trim();
  if (!query) {
    alert("Please write or select a SQL query first.");
    return;
  }

  const container = document.getElementById("sql-result-container");
  container.innerHTML = `<div class="text-center py-4"><div class="spinner-border text-primary" role="status"></div><div class="mt-2 text-muted">Executing query against MySQL 8.4 LTS...</div></div>`;

  try {
    const res = await window.api.post("/api/v1/sql/execute", { query });
    document.getElementById("sql-exec-time").textContent = `⚡ Execution time: ${res.execution_time_ms} ms (${res.row_count} rows)`;

    if (res.columns.length === 0 || res.rows.length === 0) {
      container.innerHTML = `<div class="alert alert-info">Query executed successfully. 0 rows returned.</div>`;
      return;
    }

    const ths = res.columns.map(c => `<th>${c}</th>`).join("");
    const trs = res.rows.map(row => {
      const tds = res.columns.map(c => `<td>${row[c] !== null ? row[c] : '<span class="text-muted">NULL</span>'}</td>`).join("");
      return `<tr>${tds}</tr>`;
    }).join("");

    container.innerHTML = `
      <div class="table-responsive sql-result-table-container">
        <table class="table table-sm table-bordered table-hover">
          <thead class="table-dark"><tr>${ths}</tr></thead>
          <tbody>${trs}</tbody>
        </table>
      </div>
    `;
  } catch (err) {
    container.innerHTML = `<div class="alert alert-danger"><i class="bi bi-exclamation-triangle me-2"></i><strong>Error:</strong> ${err.message}</div>`;
  }
}

async function runLiveConcurrencySimulation() {
  const container = document.getElementById("concurrency-simulation-results");
  container.innerHTML = `<div class="text-center py-3"><div class="spinner-border text-primary" role="status"></div><div class="mt-2 text-muted">Running Two-Phase Locking (2PL) and Savepoint Rollback in MySQL...</div></div>`;

  try {
    const res = await window.api.post("/api/v1/sql/concurrency-demo");
    const stepsHtml = res.steps.map(s => `
      <li class="list-group-item d-flex justify-content-between align-items-center">
        <div>
          <span class="badge bg-dark me-2">Step ${s.step}</span>
          <strong>${s.action}</strong>
          <div class="small text-muted">${s.detail}</div>
        </div>
        <span class="badge bg-${s.status === 'ROLLED_BACK' ? 'danger' : s.status === 'COMMITTED' ? 'success' : s.status === 'LOCKED' ? 'warning text-dark' : 'primary'}">
          ${s.status}
        </span>
      </li>
    `).join("");

    container.innerHTML = `
      <div class="card mb-3">
        <div class="card-header bg-dark text-white d-flex justify-content-between">
          <span><i class="bi bi-lock-fill me-2"></i>${res.demo_name}</span>
          <span class="badge bg-success">ACID Verified</span>
        </div>
        <div class="card-body">
          <h6 class="fw-bold mb-2">InnoDB ACID Guarantees:</h6>
          <ul class="small mb-3 text-muted">
            <li><strong>Atomicity:</strong> ${res.acid_guarantees.Atomicity}</li>
            <li><strong>Consistency:</strong> ${res.acid_guarantees.Consistency}</li>
            <li><strong>Isolation:</strong> ${res.acid_guarantees.Isolation}</li>
            <li><strong>Durability:</strong> ${res.acid_guarantees.Durability}</li>
          </ul>
          <h6 class="fw-bold mb-2">Audit Execution Sequence:</h6>
          <ul class="list-group">${stepsHtml}</ul>
        </div>
      </div>
    `;
  } catch (err) {
    container.innerHTML = `<div class="alert alert-danger">Simulation failed: ${err.message}</div>`;
  }
}

// ---------------------------------------------------------------------
// INITIALIZATION ON PAGE LOAD
// ---------------------------------------------------------------------
document.addEventListener("DOMContentLoaded", async () => {
  // Check if session token exists, else auto-login as admin for seamless demo
  if (!window.auth.isLoggedIn()) {
    try {
      await window.auth.login("admin", "admin123");
    } catch (err) {
      console.warn("Auto-login failed:", err.message);
    }
  }

  updateAuthUI();

  // Bind Sidebar Navigation
  document.querySelectorAll("#sidebar .nav-link").forEach(link => {
    link.addEventListener("click", e => {
      e.preventDefault();
      switchView(link.dataset.view);
    });
  });

  // Switch Role Quick Buttons
  document.querySelectorAll(".switch-role-btn").forEach(btn => {
    btn.addEventListener("click", async () => {
      const role = btn.dataset.role;
      try {
        await window.auth.switchRole(role);
        updateAuthUI();
        showToast(`Switched active session to role: ${role.toUpperCase()}`, "info");
        switchView(appState.currentView);
      } catch (err) {
        showToast(`Role switch failed: ${err.message}`, "error");
      }
    });
  });

  // Global search input for shipments
  const searchShipmentsInput = document.getElementById("search-shipments");
  if (searchShipmentsInput) {
    searchShipmentsInput.addEventListener("input", debounce(loadShipments, 400));
  }

  const filterStatusSelect = document.getElementById("filter-shipment-status");
  if (filterStatusSelect) {
    filterStatusSelect.addEventListener("change", loadShipments);
  }

  // Load default view
  switchView("dashboard");
});

function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}
