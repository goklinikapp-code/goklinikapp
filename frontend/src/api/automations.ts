import { apiClient } from '@/lib/axios'
import type {
  BroadcastPushResponse,
  NotificationCampaignLog,
  NotificationRecipientOption,
  NotificationTemplateOption,
  ScheduledNotificationItem,
  WorkflowItem,
  WorkflowTriggerType,
} from '@/types'

export type AudienceSegment = 'all_patients' | 'future_appointments' | 'inactive_patients'
export type SendTargetMode = 'segment' | 'patient'

interface PaginatedResponse<T> {
  count?: number
  next?: string | null
  previous?: string | null
  results: T[]
}

function unwrapArrayResponse<T>(data: PaginatedResponse<T> | T[]): T[] {
  if (Array.isArray(data)) return data
  if (Array.isArray(data.results)) return data.results
  return []
}

export async function getWorkflows(): Promise<WorkflowItem[]> {
  const { data } = await apiClient.get<PaginatedResponse<WorkflowItem> | WorkflowItem[]>('/notifications/workflows/')
  return unwrapArrayResponse(data)
}

export interface UpsertWorkflowPayload {
  name: string
  is_active: boolean
  trigger_type: WorkflowTriggerType
  trigger_offset?: string
  template?: string | null
}

export async function createWorkflow(payload: UpsertWorkflowPayload): Promise<WorkflowItem> {
  const { data } = await apiClient.post<WorkflowItem>('/notifications/workflows/', payload)
  return data
}

export async function updateWorkflow(id: string, payload: Partial<UpsertWorkflowPayload>): Promise<WorkflowItem> {
  const { data } = await apiClient.patch<WorkflowItem>(`/notifications/workflows/${id}/`, payload)
  return data
}

export async function getNotificationTemplates(): Promise<NotificationTemplateOption[]> {
  const { data } = await apiClient.get<PaginatedResponse<NotificationTemplateOption> | NotificationTemplateOption[]>(
    '/notifications/templates/',
    {
      params: {
        include_inactive: 1,
      },
    },
  )
  return unwrapArrayResponse(data)
}

export interface UpsertNotificationTemplatePayload {
  code: string
  title_template: string
  body_template: string
  is_active?: boolean
}

export async function createNotificationTemplate(
  payload: UpsertNotificationTemplatePayload,
): Promise<NotificationTemplateOption> {
  const { data } = await apiClient.post<NotificationTemplateOption>('/notifications/templates/', payload)
  return data
}

export async function updateNotificationTemplate(
  id: string,
  payload: Partial<UpsertNotificationTemplatePayload>,
): Promise<NotificationTemplateOption> {
  const { data } = await apiClient.patch<NotificationTemplateOption>(`/notifications/templates/${id}/`, payload)
  return data
}

interface SendMassMessagePayload {
  targetMode: SendTargetMode
  segment?: AudienceSegment
  patientId?: string
  channel?: 'push'
  title?: string
  body: string
  template_code?: string
}

export async function sendMassMessage(payload: SendMassMessagePayload): Promise<BroadcastPushResponse> {
  const requestPayload = {
    title: (payload.title || '').trim() || 'Campanha Push',
    body: payload.body,
    channel: 'push',
    target_mode: payload.targetMode,
    segment: payload.targetMode === 'segment' ? payload.segment : undefined,
    patient_id: payload.targetMode === 'patient' ? payload.patientId : undefined,
    template_code: payload.template_code || '',
  }

  const { data } = await apiClient.post<BroadcastPushResponse>('/notifications/admin/broadcast/', requestPayload)
  return data
}

export interface NotificationRecipientsPage {
  count: number
  next: string | null
  previous: string | null
  results: NotificationRecipientOption[]
}

interface SearchNotificationRecipientsParams {
  query: string
  page?: number
  pageSize?: number
}

export async function searchNotificationRecipients(
  params: SearchNotificationRecipientsParams,
): Promise<NotificationRecipientsPage> {
  const { data } = await apiClient.get<PaginatedResponse<NotificationRecipientOption> | NotificationRecipientOption[]>(
    '/notifications/admin/recipients/search/',
    {
      params: {
        q: params.query,
        page: params.page ?? 1,
        page_size: params.pageSize ?? 8,
      },
    },
  )

  if (Array.isArray(data)) {
    return {
      count: data.length,
      next: null,
      previous: null,
      results: data,
    }
  }

  return {
    count: data.count ?? 0,
    next: data.next ?? null,
    previous: data.previous ?? null,
    results: Array.isArray(data.results) ? data.results : [],
  }
}

export interface NotificationCampaignLogsPage {
  count: number
  next: string | null
  previous: string | null
  results: NotificationCampaignLog[]
}

interface GetNotificationCampaignLogsParams {
  page?: number
  pageSize?: number
  status?: string
  segment?: string
}

export async function getNotificationCampaignLogs(
  params: GetNotificationCampaignLogsParams = {},
): Promise<NotificationCampaignLogsPage> {
  const { data } = await apiClient.get<PaginatedResponse<NotificationCampaignLog> | NotificationCampaignLog[]>(
    '/notifications/admin/logs/',
    {
      params: {
        page: params.page ?? 1,
        page_size: params.pageSize ?? 10,
        status: params.status,
        segment: params.segment,
      },
    },
  )

  if (Array.isArray(data)) {
    return {
      count: data.length,
      next: null,
      previous: null,
      results: data,
    }
  }
  return {
    count: data.count ?? 0,
    next: data.next ?? null,
    previous: data.previous ?? null,
    results: Array.isArray(data.results) ? data.results : [],
  }
}

export async function clearNotificationCampaignLogs(scope: 'errors' | 'all' = 'errors') {
  const { data } = await apiClient.delete<{ deleted_count: number; scope: string }>('/notifications/admin/logs/', {
    params: { scope },
  })
  return data
}

interface ScheduleMassMessagePayload {
  run_at: string
  segment: AudienceSegment
  title?: string
  body?: string
  template?: string | null
  template_context?: Record<string, string>
  data_extra?: Record<string, string>
}

export async function scheduleMassMessage(payload: ScheduleMassMessagePayload): Promise<ScheduledNotificationItem> {
  const { data } = await apiClient.post<ScheduledNotificationItem>('/notifications/admin/scheduled/', payload)
  return data
}

export async function getScheduledNotifications(): Promise<ScheduledNotificationItem[]> {
  const { data } = await apiClient.get<PaginatedResponse<ScheduledNotificationItem> | ScheduledNotificationItem[]>(
    '/notifications/admin/scheduled/',
  )
  return unwrapArrayResponse(data)
}

export async function cancelScheduledNotification(id: string): Promise<ScheduledNotificationItem> {
  const { data } = await apiClient.patch<ScheduledNotificationItem>(`/notifications/admin/scheduled/${id}/`, {
    status: 'canceled',
  })
  return data
}
