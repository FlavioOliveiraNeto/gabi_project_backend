import { createRouter, createWebHistory } from "vue-router";
import PublicLayout from "../layouts/PublicLayout.vue";
import DashboardLayout from "../layouts/DashboardLayout.vue";
import AuthLayout from "../layouts/AuthLayout.vue";
import PublicIndex from "../pages/PublicIndex.vue";
import AdminDashboard from "../pages/AdminDashboard.vue";
import ClientDashboard from "../pages/ClientDashboard.vue";
import SignIn from "../pages/auth/SignIn.vue";
import SignUp from "../pages/auth/SignUp.vue";
import ForgotPassword from "../pages/auth/ForgotPassword.vue";
import ResetPassword from "../pages/auth/ResetPassword.vue";

const routes = [
  {
    path: "/",
    component: PublicLayout,
    children: [{ path: "", name: "home", component: PublicIndex }]
  },
  {
    path: "/dashboard",
    component: DashboardLayout,
    children: [
      { path: "admin", name: "admin-dashboard", component: AdminDashboard },
      { path: "cliente", name: "client-dashboard", component: ClientDashboard }
    ]
  },
  {
    path: "/auth",
    component: AuthLayout,
    children: [
      { path: "entrar", name: "sign-in", component: SignIn },
      { path: "cadastro", name: "sign-up", component: SignUp },
      { path: "recuperar", name: "forgot-password", component: ForgotPassword },
      { path: "resetar", name: "reset-password", component: ResetPassword }
    ]
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior() {
    return { top: 0 };
  }
});

export default router;
