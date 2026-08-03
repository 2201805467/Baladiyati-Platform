import { Routes, Route, Navigate } from "react-router-dom";
import { useAuth } from "./lib/auth";
import LoginPage from "./pages/LoginPage";
import ForgotPasswordPage from "./pages/ForgotPasswordPage";
import AdminLayout from "./components/AdminLayout";
import ReceptionPage from "./pages/ReceptionPage";
import TechnicalPage from "./pages/TechnicalPage";
import AnalyticsPage from "./pages/AnalyticsPage";
import UsersPage from "./pages/UsersPage";
import ContentPage from "./pages/ContentPage";
import DepartmentsPage from "./pages/DepartmentsPage";
import CategoriesPage from "./pages/CategoriesPage";
import NotificationsPage from "./pages/NotificationsPage";
import ReportsMapPage from "./pages/ReportsMapPage";
import PermissionsSecurityPage from "./pages/PermissionsSecurityPage";
import InitiativesPage from "./pages/InitiativesPage";
import GeoBroadcastsPage from "./pages/GeoBroadcastsPage";
import LostFoundModerationPage from "./pages/LostFoundModerationPage";
import PollsPage from "./pages/PollsPage";

function ProtectedRoute({ children, roles }: { children: React.ReactNode; roles?: string[] }) {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" replace />;
  if (roles && (!user.role || !roles.includes(user.role))) return <Navigate to="/admin" replace />;
  return <>{children}</>;
}

export default function App() {
  const { user } = useAuth();

  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/forgot-password" element={<ForgotPasswordPage />} />
      <Route path="/admin" element={
        <ProtectedRoute>
          <AdminLayout />
        </ProtectedRoute>
      }>
        <Route index element={
          user?.role === "admin" ? <Navigate to="/admin/analytics" replace /> : user?.role === "department" ? <Navigate to="/admin/technical" replace /> : <Navigate to="/admin/reception" replace />
        } />
        <Route path="reception" element={<ProtectedRoute roles={["reception"]}><ReceptionPage /></ProtectedRoute>} />
        <Route path="technical" element={<ProtectedRoute roles={["department"]}><TechnicalPage /></ProtectedRoute>} />
        <Route path="analytics" element={<ProtectedRoute roles={["admin"]}><AnalyticsPage /></ProtectedRoute>} />
        <Route path="users" element={<ProtectedRoute roles={["admin"]}><UsersPage /></ProtectedRoute>} />
        <Route path="departments" element={<ProtectedRoute roles={["admin"]}><DepartmentsPage /></ProtectedRoute>} />
        <Route path="categories" element={<ProtectedRoute roles={["admin"]}><CategoriesPage /></ProtectedRoute>} />
        <Route path="security" element={<ProtectedRoute roles={["admin"]}><PermissionsSecurityPage /></ProtectedRoute>} />
        <Route path="notifications" element={<ProtectedRoute roles={["reception", "department"]}><NotificationsPage /></ProtectedRoute>} />
        <Route path="map" element={<ProtectedRoute roles={["reception", "department", "admin"]}><ReportsMapPage /></ProtectedRoute>} />
        <Route path="content" element={<ProtectedRoute roles={["admin", "reception"]}><ContentPage /></ProtectedRoute>} />
        <Route path="initiatives" element={<ProtectedRoute roles={["admin", "reception"]}><InitiativesPage /></ProtectedRoute>} />
        <Route path="geo-broadcasts" element={<ProtectedRoute roles={["admin", "reception"]}><GeoBroadcastsPage /></ProtectedRoute>} />
        <Route path="lost-found" element={<ProtectedRoute roles={["admin", "reception"]}><LostFoundModerationPage /></ProtectedRoute>} />
        <Route path="polls" element={<ProtectedRoute roles={["admin", "reception"]}><PollsPage /></ProtectedRoute>} />
      </Route>
      <Route path="/" element={<Navigate to="/admin" replace />} />
      <Route path="*" element={<Navigate to="/admin" replace />} />
    </Routes>
  );
}
