import { useEffect, useRef, useState } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  BarChart2,
  Bell,
  Building2,
  Calendar,
  ClipboardCheck,
  HeartPulse,
  Smartphone,
  GraduationCap,
  HelpCircle,
  Info,
  LayoutDashboard,
  Moon,
  Rocket,
  Search,
  Settings,
  Share2,
  Sun,
  UserCheck,
  Users,
  Zap,
  LogOut,
  ChevronDown,
  Menu,
  Mailbox,
  Luggage,
  MessageSquareText,
  X,
} from "lucide-react";

import { Avatar } from "@/components/ui/Avatar";
import { Select } from "@/components/ui/Select";
import { Button } from "@/components/ui/Button";
import {
  getNotifications,
  getUnreadNotificationsCount,
  markAllNotificationsAsRead,
  markNotificationAsRead,
} from "@/api/notifications";
import {
  SUPPORTED_CURRENCIES,
  SUPPORTED_LANGUAGES,
  currencyLabels,
  languageLabels,
  t as translate,
  type TranslationKey,
} from "@/i18n/system";
import { cn } from "@/utils/cn";
import { resolveMediaUrl } from "@/utils/mediaUrl";
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
  { icon: ClipboardCheck, labelKey: "nav_pre_operatory", to: "/pre-operatory", permission: "pre_operatory" },
  { icon: HeartPulse, labelKey: "nav_post_operatory", to: "/post-operatory", permission: "post_operatory" },
  { icon: Calendar, labelKey: "nav_schedule", to: "/schedule", permission: "schedule" },
  { icon: Luggage, labelKey: "nav_travel_plans", to: "/travel-plans", permission: "travel_plans" },
  { icon: MessageSquareText, labelKey: "nav_chat_center", to: "/chat-center", permission: "chat_center" },
  { icon: Mailbox, labelKey: "nav_inbox", to: "/inbox", permission: "patients" },
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
  { icon: Rocket, label: "Lançamento", to: "/launch" },
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
  const [isNotificationsOpen, setIsNotificationsOpen] = useState(false);
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);
  const notificationsRef = useRef<HTMLDivElement | null>(null);
  const { theme, toggleTheme } = useTheme();
  const navigate = useNavigate();
  const location = useLocation();
  const queryClient = useQueryClient();
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

  const {
    data: unreadCount = 0,
  } = useQuery({
    queryKey: ["header-notifications-unread", user?.id],
    queryFn: getUnreadNotificationsCount,
    enabled: Boolean(user),
    refetchInterval: 30000,
  });

  const {
    data: notificationsPage,
    isFetching: isLoadingNotifications,
  } = useQuery({
    queryKey: ["header-notifications-list", user?.id],
    queryFn: () => getNotifications({ page: 1, pageSize: 8 }),
    enabled: Boolean(user),
    refetchInterval: 30000,
  });

  const notifications = notificationsPage?.results || [];

  const markAsReadMutation = useMutation({
    mutationFn: markNotificationAsRead,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["header-notifications-list"] });
      queryClient.invalidateQueries({ queryKey: ["header-notifications-unread"] });
    },
  });

  const markAllAsReadMutation = useMutation({
    mutationFn: markAllNotificationsAsRead,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["header-notifications-list"] });
      queryClient.invalidateQueries({ queryKey: ["header-notifications-unread"] });
    },
  });

  useEffect(() => {
    if (!isNotificationsOpen) return;

    const onClickOutside = (event: MouseEvent) => {
      if (!notificationsRef.current) return;
      if (notificationsRef.current.contains(event.target as Node)) return;
      setIsNotificationsOpen(false);
    };

    document.addEventListener("mousedown", onClickOutside);
    return () => document.removeEventListener("mousedown", onClickOutside);
  }, [isNotificationsOpen]);

  useEffect(() => {
    setIsMobileSidebarOpen(false);
    setIsNotificationsOpen(false);
    setIsMenuOpen(false);
  }, [location.pathname]);

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
    : resolveMediaUrl(tenantConfig.logo_url) || "/assets/logo_go_klink.png";

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
          if (item.to === "/pre-operatory" && user.role !== "clinic_master") {
            return false;
          }
          if (
            item.to === "/post-operatory" &&
            user.role !== "clinic_master" &&
            user.role !== "surgeon"
          ) {
            return false;
          }
          if (item.to === "/inbox" && user.role !== "surgeon") {
            return false;
          }
          if (
            item.to === "/travel-plans" &&
            user.role !== "clinic_master" &&
            user.role !== "secretary"
          ) {
            return false;
          }
          if (
            item.to === "/chat-center" &&
            user.role !== "clinic_master" &&
            user.role !== "secretary"
          ) {
            return false;
          }
          if (
            user.role === "surgeon" &&
            (item.to === "/app" || item.to === "/reports")
          ) {
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

  const formatNotificationDate = (value: string) => {
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) return "-";
    return parsed.toLocaleString(language === "pt" ? "pt-BR" : "en-US", {
      day: "2-digit",
      month: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  const headerSearchValue = new URLSearchParams(location.search).get("q") || "";

  const handleHeaderSearchChange = (nextValue: string) => {
    const params = new URLSearchParams(location.search);
    const normalized = nextValue.trim();
    if (normalized) {
      params.set("q", nextValue);
    } else {
      params.delete("q");
    }
    const nextSearch = params.toString();
    navigate(
      {
        pathname: location.pathname,
        search: nextSearch ? `?${nextSearch}` : "",
      },
      { replace: true },
    );
  };

  return (
    <div className="min-h-screen bg-mist">
      {isMobileSidebarOpen ? (
        <button
          type="button"
          aria-label="close-sidebar-overlay"
          className="fixed inset-0 z-40 bg-slate-900/40 lg:hidden"
          onClick={() => setIsMobileSidebarOpen(false)}
        />
      ) : null}

      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-50 w-sidebar border-r border-slate-200 bg-white p-4 transition-transform duration-200",
          "lg:translate-x-0",
          isMobileSidebarOpen ? "translate-x-0" : "-translate-x-full",
        )}
      >
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
              {"label" in item ? item.label : t(item.labelKey)}
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

      <main className="min-h-screen lg:ml-sidebar">
        <header className="sticky top-0 z-40 border-b border-slate-200 bg-white/90 px-3 py-3 backdrop-blur sm:px-4 lg:z-[60] lg:px-6">
          <div className="flex flex-wrap items-center gap-2 sm:gap-3">
            <div className="order-1 flex items-center gap-2 lg:hidden">
              <button
                type="button"
                className="rounded-lg border border-slate-200 bg-white p-2 text-slate-600 hover:bg-slate-50"
                onClick={() => setIsMobileSidebarOpen((prev) => !prev)}
                aria-label="toggle-sidebar"
              >
                {isMobileSidebarOpen ? <X className="h-4 w-4" /> : <Menu className="h-4 w-4" />}
              </button>
            </div>

            <div className="relative order-2 w-full min-w-0 sm:order-1 sm:flex-1">
              <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
              <input
                className="h-9 w-full rounded-lg border border-slate-200 bg-slate-50 pl-9 pr-3 text-sm outline-none focus:border-primary"
                placeholder={user?.role === "super_admin" ? t("search_saas") : t("search_clinic")}
                value={headerSearchValue}
                onChange={(event) => handleHeaderSearchChange(event.target.value)}
              />
            </div>

            <div className="order-1 ml-auto flex items-center gap-2 sm:order-2">
              <button
                type="button"
                onClick={toggleTheme}
                className="rounded-lg border border-slate-200 bg-white p-2 text-slate-600 hover:bg-slate-50"
                aria-label="toggle-theme"
              >
                {theme === "light" ? <Moon className="h-4 w-4" /> : <Sun className="h-4 w-4" />}
              </button>

              <div className="relative" ref={notificationsRef}>
                <button
                  type="button"
                  onClick={() => setIsNotificationsOpen((prev) => !prev)}
                  className="relative rounded-lg border border-slate-200 bg-white p-2 text-slate-600 hover:bg-slate-50"
                  aria-label="notifications"
                >
                  <Bell className="h-4 w-4" />
                  {unreadCount > 0 ? (
                    <span className="absolute -right-1 -top-1 rounded-full bg-danger px-1.5 text-[10px] font-semibold text-white">
                      {unreadCount > 99 ? "99+" : unreadCount}
                    </span>
                  ) : null}
                </button>

                {isNotificationsOpen ? (
                  <div className="absolute right-0 z-[70] mt-2 w-[92vw] max-w-[360px] rounded-lg border border-slate-200 bg-white p-3 shadow-lg">
                    <div className="mb-2 flex items-center justify-between">
                      <p className="text-sm font-semibold text-night">Notificações</p>
                      <button
                        type="button"
                        className="text-xs font-medium text-primary hover:underline disabled:opacity-50"
                        onClick={() => markAllAsReadMutation.mutate()}
                        disabled={markAllAsReadMutation.isPending || unreadCount <= 0}
                      >
                        Marcar todas
                      </button>
                    </div>

                    <div className="max-h-96 space-y-2 overflow-y-auto pr-1">
                      {isLoadingNotifications ? (
                        <p className="caption py-6 text-center">Carregando notificações...</p>
                      ) : notifications.length === 0 ? (
                        <p className="caption py-6 text-center">Nenhuma notificação encontrada.</p>
                      ) : (
                        notifications.map((item) => (
                          <button
                            key={item.id}
                            type="button"
                            className={cn(
                              "w-full rounded-lg border p-3 text-left transition",
                              item.is_read
                                ? "border-slate-200 bg-white hover:bg-slate-50"
                                : "border-primary/30 bg-primary/5 hover:bg-primary/10",
                            )}
                            onClick={() => {
                              if (item.is_read || markAsReadMutation.isPending) return;
                              markAsReadMutation.mutate(item.id);
                            }}
                          >
                            <div className="flex items-start justify-between gap-2">
                              <p className="text-sm font-semibold text-night">{item.title}</p>
                              <span className="caption whitespace-nowrap">
                                {formatNotificationDate(item.created_at)}
                              </span>
                            </div>
                            <p className="mt-1 text-xs text-slate-600">{item.body}</p>
                          </button>
                        ))
                      )}
                    </div>
                  </div>
                ) : null}
              </div>

              <div className="hidden sm:block">
                <Select
                  value={period}
                  onChange={(event) => setPeriod(event.target.value as typeof period)}
                  className="h-9 min-w-44 bg-white"
                >
                  <option value="today">{t("period_today")}</option>
                  <option value="week">{t("period_week")}</option>
                  <option value="month">{t("period_month")}</option>
                  <option value="last_30_days">{t("period_last_30_days")}</option>
                </Select>
              </div>

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
                  <div className="absolute right-0 z-[70] mt-2 w-64 rounded-lg border border-slate-200 bg-white p-3 shadow-lg">
                    <p className="text-sm font-semibold text-night">
                      {user?.full_name || "GoKlinik Admin"}
                    </p>
                    <p className="caption">{userRoleLabel}</p>

                    <div className="mt-3 border-t border-slate-100 pt-3">
                      <p className="caption mb-2">{t("language")}</p>
                      <Select
                        className="h-9 w-full"
                        value={language}
                        onChange={(event) => setLanguage(event.target.value as typeof language)}
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
                        onChange={(event) => setCurrency(event.target.value as typeof currency)}
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

            <div className="order-3 w-full sm:hidden">
              <Select
                value={period}
                onChange={(event) => setPeriod(event.target.value as typeof period)}
                className="h-9 w-full bg-white"
              >
                <option value="today">{t("period_today")}</option>
                <option value="week">{t("period_week")}</option>
                <option value="month">{t("period_month")}</option>
                <option value="last_30_days">{t("period_last_30_days")}</option>
              </Select>
            </div>
          </div>
        </header>

        <div className="p-3 sm:p-4 lg:p-6">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
