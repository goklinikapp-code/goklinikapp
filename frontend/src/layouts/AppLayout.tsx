import { useEffect, useState } from "react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import {
  BarChart2,
  Bell,
  Building2,
  Calendar,
  Smartphone,
  GraduationCap,
  HelpCircle,
  Info,
  LayoutDashboard,
  Moon,
  Search,
  Settings,
  Share2,
  Sun,
  UserCheck,
  Users,
  Zap,
  LogOut,
  ChevronDown,
} from "lucide-react";

import { Avatar } from "@/components/ui/Avatar";
import { Select } from "@/components/ui/Select";
import { Button } from "@/components/ui/Button";
import {
  SUPPORTED_CURRENCIES,
  SUPPORTED_LANGUAGES,
  currencyLabels,
  languageLabels,
  t as translate,
  type TranslationKey,
} from "@/i18n/system";
import { cn } from "@/utils/cn";
import { useTheme } from "@/hooks/useTheme";
import { useAuthStore } from "@/stores/authStore";
import { usePreferencesStore } from "@/stores/preferencesStore";
import { useTenantStore } from "@/stores/tenantStore";
import { useUIStore } from "@/stores/uiStore";
import {
  hasAccessPermission,
  type AccessPermissionKey,
} from "@/utils/accessPermissions";

const clinicNavItems = [
  { icon: Smartphone, labelKey: "nav_app", to: "/app", permission: "app" },
  { icon: LayoutDashboard, labelKey: "nav_dashboard", to: "/dashboard", permission: "dashboard" },
  { icon: Users, labelKey: "nav_patients", to: "/patients", permission: "patients" },
  { icon: Calendar, labelKey: "nav_schedule", to: "/schedule", permission: "schedule" },
  { icon: BarChart2, labelKey: "nav_reports", to: "/reports", permission: "reports" },
  { icon: Share2, labelKey: "nav_referrals", to: "/referrals", permission: "referrals" },
  { icon: UserCheck, labelKey: "nav_team", to: "/team", permission: "team" },
  { icon: Zap, labelKey: "nav_automations", to: "/automations", permission: "automations" },
  { icon: Settings, labelKey: "nav_settings", to: "/settings", permission: "settings" },
  { icon: GraduationCap, labelKey: "nav_tutorials", to: "/tutorials", permission: "tutorials" },
] as const;

const saasNavItems = [
  { icon: LayoutDashboard, labelKey: "nav_saas_dashboard", to: "/dashboard" },
  { icon: Building2, labelKey: "nav_clients", to: "/clients" },
  { icon: UserCheck, labelKey: "nav_sellers", to: "/sellers" },
  { icon: GraduationCap, labelKey: "nav_tutorials", to: "/tutorials" },
] as const;

const supportItems = [
  { icon: HelpCircle, labelKey: "support" },
  { icon: Info, labelKey: "system" },
] as const;

const roleLabelMap: Record<string, TranslationKey> = {
  super_admin: "role_super_admin",
  clinic_master: "role_clinic_master",
  surgeon: "role_surgeon",
  secretary: "role_secretary",
  nurse: "role_nurse",
  patient: "role_patient",
};

export function AppLayout() {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const { theme, toggleTheme } = useTheme();
  const navigate = useNavigate();
  const { user, logout, tenant } = useAuthStore();
  const { tenantConfig, loadTenantBranding, setTenantConfig } = useTenantStore();
  const { period, setPeriod } = useUIStore();

  const language = usePreferencesStore((state) => state.language);
  const currency = usePreferencesStore((state) => state.currency);
  const setLanguage = usePreferencesStore((state) => state.setLanguage);
  const setCurrency = usePreferencesStore((state) => state.setCurrency);
  const useAutomaticCurrency = usePreferencesStore(
    (state) => state.useAutomaticCurrency,
  );

  const t = (key: TranslationKey) => translate(language, key);

  useEffect(() => {
    if (user?.role === "super_admin") {
      setTenantConfig({
        name: "GoKlinik SaaS",
        slug: "goklinik-saas",
        primary_color: "#0D5C73",
        secondary_color: "#4A7C59",
        accent_color: "#C8992E",
        clinic_addresses: ["SaaS Platform"],
        logo_url: "/assets/logo_go_klink.png",
        favicon_url: "/assets/favicon_go_klink.png",
        ai_assistant_prompt: "",
      });
      return;
    }
    const slug = tenant?.slug || user?.tenant?.slug || "goklinik-demo";
    void loadTenantBranding(slug);
  }, [loadTenantBranding, setTenantConfig, tenant?.slug, user?.role, user?.tenant?.slug]);

  const isSaasOwner = user?.role === "super_admin";

  const clinicName = isSaasOwner
    ? t("clinic_label_saas")
    : tenantConfig.name || tenant?.name || user?.tenant?.name || "Clínica";

  const sidebarLogoSrc = isSaasOwner
    ? "/assets/logo_go_klink.png"
    : tenantConfig.logo_url || "/assets/logo_go_klink.png";

  const userRoleLabel = t(
    roleLabelMap[user?.role || ""] || "role_clinic_master",
  );
  const navItems =
    user?.role === "super_admin"
      ? saasNavItems
      : clinicNavItems.filter((item) => {
          if (!user) return false;
          if ((item.to === "/referrals" || item.to === "/tutorials") && user.role !== "clinic_master") {
            return false;
          }
          return hasAccessPermission(
            user,
            item.permission as AccessPermissionKey,
          );
        });

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  return (
    <div className="min-h-screen bg-mist">
      <aside className="fixed inset-y-0 left-0 z-30 w-sidebar border-r border-slate-200 bg-white p-4">
        <div className="mb-6 border-b border-slate-100 pb-4">
          <img
            src={sidebarLogoSrc}
            alt="GoKlinik"
            className="h-10 w-auto object-contain"
            onError={(event) => {
              event.currentTarget.src = "/assets/logo_go_klink.png";
            }}
          />
          <p className="caption mt-2">{clinicName}</p>
        </div>

        <nav className="space-y-1">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition",
                  isActive
                    ? "bg-primary text-white"
                    : "text-neutral hover:bg-mist hover:text-night",
                )
              }
            >
              <item.icon className="h-4 w-4" />
              {t(item.labelKey)}
            </NavLink>
          ))}
        </nav>

        <div className="mt-6 border-t border-slate-100 pt-4">
          {supportItems.map((item) => (
            <button
              key={item.labelKey}
              type="button"
              className="mb-1 flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm text-neutral transition hover:bg-mist"
            >
              <item.icon className="h-4 w-4" />
              {t(item.labelKey)}
            </button>
          ))}
        </div>

        <div className="absolute bottom-4 left-4 right-4 rounded-lg bg-tealIce p-3">
          <div className="flex items-center gap-2">
            <Avatar
              name={user?.full_name || "GoKlinik Admin"}
              src={user?.avatar_url}
              className="h-8 w-8"
            />
            <div className="min-w-0">
              <p className="truncate text-xs font-semibold text-night">
                {user?.full_name || "GoKlinik Admin"}
              </p>
              <p className="caption truncate">{userRoleLabel}</p>
            </div>
          </div>
        </div>
      </aside>

      <main className="ml-sidebar min-h-screen">
        <header className="sticky top-0 z-20 border-b border-slate-200 bg-white/90 px-6 py-3 backdrop-blur">
          <div className="flex items-center gap-3">
            <div className="relative flex-1">
              <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
              <input
                className="h-9 w-full rounded-lg border border-slate-200 bg-slate-50 pl-9 pr-3 text-sm outline-none focus:border-primary"
                placeholder={
                  user?.role === "super_admin"
                    ? t("search_saas")
                    : t("search_clinic")
                }
              />
            </div>

            <button
              type="button"
              onClick={toggleTheme}
              className="rounded-lg border border-slate-200 bg-white p-2 text-slate-600 hover:bg-slate-50"
              aria-label="toggle-theme"
            >
              {theme === "light" ? (
                <Moon className="h-4 w-4" />
              ) : (
                <Sun className="h-4 w-4" />
              )}
            </button>

            <button
              type="button"
              className="relative rounded-lg border border-slate-200 bg-white p-2 text-slate-600 hover:bg-slate-50"
            >
              <Bell className="h-4 w-4" />
              <span className="absolute -right-1 -top-1 rounded-full bg-danger px-1.5 text-[10px] font-semibold text-white">
                3
              </span>
            </button>

            <Select
              value={period}
              onChange={(event) =>
                setPeriod(event.target.value as typeof period)
              }
              className="h-9 min-w-44 bg-white"
            >
              <option value="today">{t("period_today")}</option>
              <option value="week">{t("period_week")}</option>
              <option value="month">{t("period_month")}</option>
              <option value="last_30_days">{t("period_last_30_days")}</option>
            </Select>

            <div className="relative">
              <button
                type="button"
                onClick={() => setIsMenuOpen((prev) => !prev)}
                className="flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-2 py-1.5"
              >
                <Avatar
                  name={user?.full_name || "Admin"}
                  src={user?.avatar_url}
                  className="h-7 w-7"
                />
                <ChevronDown className="h-4 w-4 text-slate-500" />
              </button>

              {isMenuOpen ? (
                <div className="absolute right-0 mt-2 w-64 rounded-lg border border-slate-200 bg-white p-3 shadow-lg">
                  <p className="text-sm font-semibold text-night">
                    {user?.full_name || "GoKlinik Admin"}
                  </p>
                  <p className="caption">{userRoleLabel}</p>

                  <div className="mt-3 border-t border-slate-100 pt-3">
                    <p className="caption mb-2">{t("language")}</p>
                    <Select
                      className="h-9 w-full"
                      value={language}
                      onChange={(event) =>
                        setLanguage(event.target.value as typeof language)
                      }
                    >
                      {SUPPORTED_LANGUAGES.map((value) => (
                        <option key={value} value={value}>
                          {languageLabels[value]}
                        </option>
                      ))}
                    </Select>
                  </div>

                  <div className="mt-3">
                    <p className="caption mb-2">{t("currency")}</p>
                    <Select
                      className="h-9 w-full"
                      value={currency}
                      onChange={(event) =>
                        setCurrency(event.target.value as typeof currency)
                      }
                    >
                      {SUPPORTED_CURRENCIES.map((value) => (
                        <option key={value} value={value}>
                          {currencyLabels[value]}
                        </option>
                      ))}
                    </Select>
                    <Button
                      className="mt-2 w-full"
                      variant="secondary"
                      onClick={useAutomaticCurrency}
                    >
                      {t("currency_auto")}
                    </Button>
                  </div>

                  <Button
                    className="mt-3 w-full"
                    variant="secondary"
                    onClick={handleLogout}
                  >
                    <LogOut className="h-4 w-4" />
                    {t("logout")}
                  </Button>
                </div>
              ) : null}
            </div>
          </div>
        </header>

        <div className="p-6">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
