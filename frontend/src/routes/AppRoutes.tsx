import { Navigate, Route, Routes } from "react-router-dom";
import type { ReactNode } from "react";

import { AppLayout } from "@/layouts/AppLayout";
import { AuthLayout } from "@/layouts/AuthLayout";
import { LoginPage } from "@/pages/Auth/Login";
import { SaaSSignupPage } from "@/pages/Auth/SaaSSignup";
import { SaaSClinicInviteAcceptPage } from "@/pages/Auth/SaaSClinicInviteAccept";
import AppDownloadsPage from "@/pages/AppDownloads";
import TutorialsPage from "@/pages/Tutorials";
import DashboardPage from "@/pages/Dashboard";
import SurgeonDashboardPage from "@/pages/SurgeonDashboard";
import SaaSDashboardPage from "@/pages/SaaSDashboard";
import SaaSClientsPage from "@/pages/SaaSClients";
import SaaSSellersPage from "@/pages/SaaSSellers";
import SaaSLaunchPage from "@/pages/SaaSLaunch";
import PatientsPage from "@/pages/Patients";
import SchedulePage from "@/pages/Schedule";
import TravelPlansPage from "@/pages/TravelPlans";
import ChatCenterPage from "@/pages/ChatCenter";
import ReportsPage from "@/pages/Reports";
import InboxPage from "@/pages/Inbox";
import ReferralsPage from "@/pages/Referrals";
import TeamPage from "@/pages/Team";
import AutomationsPage from "@/pages/Automations";
import SettingsPage from "@/pages/Settings";
import PatientDetailPage from "@/pages/PatientDetail";
import PreOperatoryPage from "@/pages/PreOperatory";
import PostOperatoryPage from "@/pages/PostOperatory";
import { RouteErrorBoundary } from "@/components/shared/RouteErrorBoundary";
import { PrivateRoute } from "@/routes/PrivateRoute";
import { useAuthStore } from "@/stores/authStore";
import type { UserRole } from "@/types";
import {
  hasAccessPermission,
  type AccessPermissionKey,
} from "@/utils/accessPermissions";

function RoleRoute({
  allow,
  permission,
  children,
}: {
  allow: UserRole[];
  permission?: AccessPermissionKey;
  children: ReactNode;
}) {
  const user = useAuthStore((state) => state.user);
  if (!user || !allow.includes(user.role)) {
    return <Navigate to="/dashboard" replace />;
  }
  if (permission && !hasAccessPermission(user, permission)) {
    return <Navigate to="/dashboard" replace />;
  }
  return <>{children}</>;
}

function RoleBasedDashboard() {
  const user = useAuthStore((state) => state.user);
  if (user?.role === "super_admin") {
    return <SaaSDashboardPage />;
  }
  if (user?.role === "surgeon") {
    return <SurgeonDashboardPage />;
  }
  return <DashboardPage />;
}

export function AppRoutes() {
  const clinicRoles: UserRole[] = [
    "clinic_master",
    "surgeon",
    "secretary",
    "nurse",
  ];
  const clinicRolesWithoutSurgeon: UserRole[] = [
    "clinic_master",
    "secretary",
    "nurse",
  ];
  const tutorialRoles: UserRole[] = ["super_admin", "clinic_master"];

  return (
    <Routes>
      <Route
        path="/login"
        element={
          <AuthLayout>
            <LoginPage />
          </AuthLayout>
        }
      />
      <Route
        path="/signup"
        element={
          <AuthLayout>
            <SaaSSignupPage />
          </AuthLayout>
        }
      />
      <Route
        path="/signup/clinic-invite"
        element={
          <AuthLayout>
            <SaaSClinicInviteAcceptPage />
          </AuthLayout>
        }
      />

      <Route
        element={
          <PrivateRoute>
            <AppLayout />
          </PrivateRoute>
        }
      >
        <Route path="/dashboard" element={<RoleBasedDashboard />} />
        <Route
          path="/app"
          element={
            <RoleRoute allow={clinicRolesWithoutSurgeon} permission="app">
              <AppDownloadsPage />
            </RoleRoute>
          }
        />
        <Route
          path="/tutorials"
          element={
            <RoleRoute allow={tutorialRoles}>
              <TutorialsPage />
            </RoleRoute>
          }
        />
        <Route
          path="/clients"
          element={
            <RoleRoute allow={["super_admin"]}>
              <SaaSClientsPage />
            </RoleRoute>
          }
        />
        <Route
          path="/sellers"
          element={
            <RoleRoute allow={["super_admin"]}>
              <SaaSSellersPage />
            </RoleRoute>
          }
        />
        <Route
          path="/launch"
          element={
            <RoleRoute allow={["super_admin"]}>
              <SaaSLaunchPage />
            </RoleRoute>
          }
        />
        <Route
          path="/patients"
          element={
            <RoleRoute allow={clinicRoles} permission="patients">
              <PatientsPage />
            </RoleRoute>
          }
        />
        <Route
          path="/patients/:id"
          element={
            <RoleRoute allow={clinicRoles} permission="patients">
              <PatientDetailPage />
            </RoleRoute>
          }
        />
        <Route
          path="/schedule"
          element={
            <RoleRoute allow={clinicRoles} permission="schedule">
              <SchedulePage />
            </RoleRoute>
          }
        />
        <Route
          path="/travel-plans"
          element={
            <RoleRoute allow={["clinic_master", "secretary"]} permission="travel_plans">
              <TravelPlansPage />
            </RoleRoute>
          }
        />
        <Route
          path="/chat-center"
          element={
            <RoleRoute allow={["clinic_master", "secretary"]} permission="chat_center">
              <ChatCenterPage />
            </RoleRoute>
          }
        />
        <Route
          path="/pre-operatory"
          element={
            <RoleRoute allow={["clinic_master", "surgeon", "nurse"]} permission="pre_operatory">
              <PreOperatoryPage />
            </RoleRoute>
          }
        />
        <Route
          path="/post-operatory"
          element={
            <RoleRoute allow={["clinic_master", "surgeon", "nurse"]} permission="post_operatory">
              <PostOperatoryPage />
            </RoleRoute>
          }
        />
        <Route
          path="/reports"
          element={
            <RoleRoute allow={clinicRolesWithoutSurgeon} permission="reports">
              <RouteErrorBoundary title="Não foi possível abrir os relatórios.">
                <ReportsPage />
              </RouteErrorBoundary>
            </RoleRoute>
          }
        />
        <Route
          path="/inbox"
          element={
            <RoleRoute allow={["surgeon"]}>
              <InboxPage />
            </RoleRoute>
          }
        />
        <Route
          path="/team"
          element={
            <RoleRoute allow={clinicRoles} permission="team">
              <TeamPage />
            </RoleRoute>
          }
        />
        <Route
          path="/referrals"
          element={
            <RoleRoute allow={["clinic_master"]}>
              <ReferralsPage />
            </RoleRoute>
          }
        />
        <Route
          path="/automations"
          element={
            <RoleRoute allow={clinicRoles} permission="automations">
              <AutomationsPage />
            </RoleRoute>
          }
        />
        <Route
          path="/settings"
          element={
            <RoleRoute allow={["clinic_master"]} permission="settings">
              <SettingsPage />
            </RoleRoute>
          }
        />
      </Route>

      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}
