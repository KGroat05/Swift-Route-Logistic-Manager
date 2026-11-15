/**
 * Swift Route Logistics Manager - API Client Module
 * Handles all REST communication with FastAPI backend.
 */
const API_BASE = window.location.origin;

class ApiClient {
  constructor() {
    this.token = localStorage.getItem("swiftroute_token") || null;
  }

  setToken(token) {
    this.token = token;
    if (token) {
      localStorage.setItem("swiftroute_token", token);
    } else {
      localStorage.removeItem("swiftroute_token");
    }
  }

  getHeaders(customHeaders = {}) {
    const headers = {
      "Content-Type": "application/json",
      ...customHeaders
    };
    if (this.token) {
      headers["Authorization"] = `Bearer ${this.token}`;
    }
    return headers;
  }

  async request(endpoint, options = {}) {
    const url = `${API_BASE}${endpoint}`;
    const config = {
      ...options,
      headers: this.getHeaders(options.headers)
    };

    try {
      const response = await fetch(url, config);

      // Handle 401 Unauthorized (session expired or invalid)
      if (response.status === 401 && !endpoint.includes("/auth/login")) {
        this.setToken(null);
        window.dispatchEvent(new CustomEvent("auth:unauthorized"));
        throw new Error("Session expired. Please log in again.");
      }

      if (response.status === 204) {
        return null;
      }

      const data = await response.json().catch(() => null);

      if (!response.ok) {
        const errorMsg = data && (data.detail || data.message) ? data.detail || data.message : `HTTP ${response.status}`;
        throw new Error(errorMsg);
      }

      return data;
    } catch (err) {
      console.error(`API Error [${endpoint}]:`, err.message);
      throw err;
    }
  }

  get(endpoint, params = {}) {
    const query = new URLSearchParams(params).toString();
    const url = query ? `${endpoint}?${query}` : endpoint;
    return this.request(url, { method: "GET" });
  }

  post(endpoint, body) {
    return this.request(endpoint, {
      method: "POST",
      body: JSON.stringify(body)
    });
  }

  put(endpoint, body = {}) {
    return this.request(endpoint, {
      method: "PUT",
      body: JSON.stringify(body)
    });
  }

  delete(endpoint) {
    return this.request(endpoint, { method: "DELETE" });
  }
}

window.api = new ApiClient();
