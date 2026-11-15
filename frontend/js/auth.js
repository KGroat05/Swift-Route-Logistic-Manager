/**
 * Swift Route Logistics Manager - Authentication & Session Module
 */
class AuthManager {
  constructor() {
    this.currentUser = JSON.parse(localStorage.getItem("swiftroute_user") || "null");
  }

  isLoggedIn() {
    return !!window.api.token && !!this.currentUser;
  }

  getCurrentUser() {
    return this.currentUser;
  }

  getRole() {
    return this.currentUser ? this.currentUser.role : "GUEST";
  }

  isAdmin() {
    return this.getRole() === "ADMIN";
  }

  isDispatcher() {
    return this.getRole() === "DISPATCHER" || this.isAdmin();
  }

  isViewer() {
    return this.getRole() === "VIEWER";
  }

  async login(username, password) {
    const data = await window.api.post("/api/v1/auth/login", { username, password });
    window.api.setToken(data.access_token);
    this.currentUser = data.user;
    localStorage.setItem("swiftroute_user", JSON.stringify(data.user));
    window.dispatchEvent(new CustomEvent("auth:login", { detail: data.user }));
    return data.user;
  }

  async switchRole(roleUsername) {
    const passwordMap = {
      admin: "admin123",
      dispatcher: "dispatcher123",
      viewer: "viewer123"
    };
    const password = passwordMap[roleUsername] || `${roleUsername}123`;
    return await this.login(roleUsername, password);
  }

  logout() {
    window.api.setToken(null);
    this.currentUser = null;
    localStorage.removeItem("swiftroute_user");
    window.dispatchEvent(new CustomEvent("auth:logout"));
  }
}

window.auth = new AuthManager();
