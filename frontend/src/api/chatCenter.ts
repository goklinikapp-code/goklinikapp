import { apiClient } from '@/lib/axios'

export type AIMessageRole = 'user' | 'assistant'
export type AIMessageSource = 'patient' | 'ai' | 'staff' | 'system'

export interface ChatAISender {
  id: string
  name: string
  role: string
}

export interface ChatAIMessage {
  id: string
  role: AIMessageRole
  source: AIMessageSource
  sender: ChatAISender | null
  content: string
  created_at: string
}

export interface ChatAIConversationSummary {
  patient_id: string
  patient_name: string
  patient_email: string
  patient_avatar_url: string
  last_message_at: string
  last_message_preview: string
  last_message_role: AIMessageRole | ''
  last_message_source: AIMessageSource | ''
  force_human: boolean
  effective_ai_enabled: boolean
}

export interface ChatAIConversationListResponse {
  global_ai_enabled: boolean
  results: ChatAIConversationSummary[]
}

export interface ChatAIConversationDetailResponse {
  patient: {
    id: string
    name: string
    email: string
    avatar_url: string
  }
  global_ai_enabled: boolean
  force_human: boolean
  effective_ai_enabled: boolean
  messages: ChatAIMessage[]
}

export interface ChatAISettings {
  ai_enabled: boolean
  updated_at: string
}

export interface ChatAITypingStatusResponse {
  is_typing: boolean
  expires_at?: string | null
}

export async function getChatAISettings(): Promise<ChatAISettings> {
  const { data } = await apiClient.get<ChatAISettings>('/chat/admin/ai/settings/')
  return data
}

export async function updateChatAISettings(aiEnabled: boolean): Promise<ChatAISettings> {
  const { data } = await apiClient.put<ChatAISettings>('/chat/admin/ai/settings/', {
    ai_enabled: aiEnabled,
  })
  return data
}

export async function listChatAIConversations(search?: string): Promise<ChatAIConversationListResponse> {
  const { data } = await apiClient.get<ChatAIConversationListResponse>('/chat/admin/ai/conversations/', {
    params: search ? { search } : undefined,
  })
  return {
    global_ai_enabled: data?.global_ai_enabled ?? true,
    results: Array.isArray(data?.results) ? data.results : [],
  }
}

export async function getChatAIConversationMessages(
  patientId: string,
): Promise<ChatAIConversationDetailResponse> {
  const { data } = await apiClient.get<ChatAIConversationDetailResponse>(
    `/chat/admin/ai/patients/${patientId}/messages/`,
  )
  return data
}

export async function sendChatAIStaffMessage(
  patientId: string,
  content: string,
): Promise<ChatAIMessage> {
  const { data } = await apiClient.post<ChatAIMessage>(
    `/chat/admin/ai/patients/${patientId}/messages/`,
    { content },
  )
  return data
}

export async function setChatAIPatientMode(patientId: string, forceHuman: boolean): Promise<{
  force_human: boolean
  effective_ai_enabled: boolean
}> {
  const { data } = await apiClient.put<{
    force_human: boolean
    effective_ai_enabled: boolean
  }>(
    `/chat/admin/ai/patients/${patientId}/mode/`,
    { force_human: forceHuman },
  )
  return data
}

export async function setChatAITypingStatus(
  patientId: string,
  isTyping: boolean,
): Promise<ChatAITypingStatusResponse> {
  const { data } = await apiClient.put<ChatAITypingStatusResponse>(
    `/chat/admin/ai/patients/${patientId}/typing/`,
    { is_typing: isTyping },
  )
  return data
}
