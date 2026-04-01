import { apiClient } from "@/lib/axios";
import type { AuthResponse } from "@/types";
import type { SupportedLanguage } from "@/i18n/system";

export type SaaSClientPlan = "starter" | "professional" | "enterprise";

export interface SaaSDashboardTopSeller {
  id: string;
  full_name: string;
  invites_sent: number;
  invites_accepted: number;
  signups_completed: number;
}

export interface SaaSDashboardData {
  total_clinics: number;
  active_clinics: number;
  inactive_clinics: number;
  new_clinics_this_month: number;
  clinic_master_users: number;
  clinical_staff_users: number;
  total_patients: number;
  total_appointments_this_month: number;
  total_revenue_this_month: number;
  total_sellers: number;
  active_sellers: number;
  seller_invites_sent: number;
  seller_invites_accepted: number;
  seller_signups_completed: number;
  top_sellers: SaaSDashboardTopSeller[];
  recent_clients: Array<{
    id: string;
    name: string;
    slug: string;
    plan: string;
    is_active: boolean;
    created_at: string;
    primary_contact_name: string;
    primary_contact_email: string;
  }>;
}

export interface SaaSClient {
  id: string;
  name: string;
  slug: string;
  plan: SaaSClientPlan;
  is_active: boolean;
  created_at: string;
  primary_contact_name: string;
  primary_contact_email: string;
  primary_contact_phone: string;
  primary_contact_tax_number: string;
  patients_count: number;
  appointments_next_30_days: number;
  staff_count: number;
  clinic_addresses: string[];
}

export interface SaaSSeller {
  id: string;
  full_name: string;
  email: string;
  phone: string;
  ref_code: string;
  invite_code: string;
  invite_link: string;
  is_active: boolean;
  created_at: string;
  metrics: {
    invites_sent: number;
    invites_accepted: number;
    signups_completed: number;
    leads_total: number;
  };
}

export interface SaaSClientCreatePayload {
  mode: "direct" | "invite";
  clinic_name: string;
  plan: SaaSClientPlan;
  clinic_addresses?: string[];
  owner_full_name: string;
  owner_email: string;
  owner_phone?: string;
  owner_tax_number?: string;
  password?: string;
  seller_id?: string;
  language?: SupportedLanguage;
}

export interface SaaSClientUpdatePayload {
  clinic_name?: string;
  plan?: SaaSClientPlan;
  clinic_addresses?: string[];
  is_active?: boolean;
  owner_full_name?: string;
  owner_email?: string;
  owner_phone?: string;
  owner_tax_number?: string;
  password?: string;
}

export interface SaaSClientCreateInviteResponse {
  mode: "invite";
  invite_request_id: string;
  invite_token: string;
  detail: string;
}

export interface SaaSSellerCreatePayload {
  full_name: string;
  email: string;
  phone?: string;
  is_active?: boolean;
}

export interface SaaSSignupRequestPayload {
  clinic_name: string;
  full_name: string;
  email: string;
  phone?: string;
  tax_number?: string;
  password: string;
  plan?: SaaSClientPlan;
  seller_code?: string;
  language?: SupportedLanguage;
}

export interface SaaSSignupRequestResponse {
  detail: string;
  email: string;
  request_id: string;
  expires_in_minutes: number;
}

export interface SaaSInvitePreviewResponse {
  clinic_name: string;
  owner_full_name: string;
  owner_email: string;
  plan: SaaSClientPlan;
  expires_at: string | null;
}

export interface SaaSAISettings {
  api_key_masked: string;
  has_api_key: boolean;
  key_source: "env" | "panel";
  updated_at: string;
}

export async function getSaaSDashboard(): Promise<SaaSDashboardData> {
  const { data } = await apiClient.get<SaaSDashboardData>(
    "/auth/saas/dashboard/",
  );
  return data;
}

export async function getSaaSClients(): Promise<SaaSClient[]> {
  const { data } = await apiClient.get<SaaSClient[]>("/auth/saas/clients/");
  return data;
}

export async function getSaaSClient(clientId: string): Promise<SaaSClient> {
  const { data } = await apiClient.get<SaaSClient>(
    `/auth/saas/clients/${clientId}/`,
  );
  return data;
}

export async function createSaaSClient(
  payload: SaaSClientCreatePayload,
): Promise<SaaSClient | SaaSClientCreateInviteResponse> {
  const { data } = await apiClient.post<
    SaaSClient | SaaSClientCreateInviteResponse
  >("/auth/saas/clients/", payload);
  return data;
}

export async function updateSaaSClient(
  clientId: string,
  payload: SaaSClientUpdatePayload,
): Promise<SaaSClient> {
  const { data } = await apiClient.patch<SaaSClient>(
    `/auth/saas/clients/${clientId}/`,
    payload,
  );
  return data;
}

export async function disableSaaSClient(clientId: string): Promise<void> {
  await apiClient.delete(`/auth/saas/clients/${clientId}/`);
}

export async function getSaaSSellers(): Promise<SaaSSeller[]> {
  const { data } = await apiClient.get<SaaSSeller[]>("/auth/saas/sellers/");
  return data;
}

export async function getSaaSSeller(sellerId: string): Promise<SaaSSeller> {
  const { data } = await apiClient.get<SaaSSeller>(
    `/auth/saas/sellers/${sellerId}/`,
  );
  return data;
}

export async function createSaaSSeller(
  payload: SaaSSellerCreatePayload,
): Promise<SaaSSeller> {
  const { data } = await apiClient.post<SaaSSeller>(
    "/auth/saas/sellers/",
    payload,
  );
  return data;
}

export async function updateSaaSSeller(
  sellerId: string,
  payload: Partial<SaaSSellerCreatePayload>,
): Promise<SaaSSeller> {
  const { data } = await apiClient.patch<SaaSSeller>(
    `/auth/saas/sellers/${sellerId}/`,
    payload,
  );
  return data;
}

export async function deleteSaaSSeller(sellerId: string): Promise<void> {
  await apiClient.delete(`/auth/saas/sellers/${sellerId}/`);
}

export async function requestSaaSSignupCode(
  payload: SaaSSignupRequestPayload,
): Promise<SaaSSignupRequestResponse> {
  const { data } = await apiClient.post<SaaSSignupRequestResponse>(
    "/auth/saas/signup/request-code/",
    payload,
  );
  return data;
}

export async function verifySaaSSignupCode(payload: {
  email: string;
  code: string;
}): Promise<AuthResponse> {
  const { data } = await apiClient.post<AuthResponse>(
    "/auth/saas/signup/verify-code/",
    payload,
  );
  return data;
}

export async function getSaaSInvitePreview(
  token: string,
): Promise<SaaSInvitePreviewResponse> {
  const { data } = await apiClient.get<SaaSInvitePreviewResponse>(
    `/auth/saas/signup/invite/${token}/`,
  );
  return data;
}

export async function acceptSaaSInvite(payload: {
  token: string;
  password: string;
  phone?: string;
  tax_number?: string;
}): Promise<AuthResponse> {
  const { data } = await apiClient.post<AuthResponse>(
    "/auth/saas/signup/invite/accept/",
    payload,
  );
  return data;
}

export async function getSaaSSellerByCode(
  code: string,
): Promise<{ full_name: string; invite_code: string }> {
  const { data } = await apiClient.get<{
    full_name: string;
    invite_code: string;
  }>(`/auth/saas/signup/seller/${code}/`);
  return data;
}

export async function getSaaSAISettings(): Promise<SaaSAISettings> {
  const { data } = await apiClient.get<SaaSAISettings>(
    "/auth/saas/settings/ai/",
  );
  return data;
}

export async function updateSaaSAISettings(payload: {
  api_key?: string;
}): Promise<SaaSAISettings> {
  const { data } = await apiClient.patch<SaaSAISettings>(
    "/auth/saas/settings/ai/",
    payload,
  );
  return data;
}
