import { apiClient } from '@/lib/axios'

export interface TutorialVideo {
  id: string
  title: string
  description: string
  youtube_url: string
  embed_url: string
  thumbnail_url: string
  duration_minutes: number | null
  order_index: number
  is_published: boolean
  created_at: string
  updated_at: string
  progress_completed: boolean
  progress_completed_at: string | null
}

export interface TutorialSummary {
  total_videos: number
  completed_videos: number
  remaining_videos: number
  completion_percent: number
}

export interface TutorialsResponse {
  videos: TutorialVideo[]
  summary: TutorialSummary
}

export interface TutorialWritePayload {
  title: string
  description?: string
  youtube_url: string
  thumbnail_url?: string
  duration_minutes?: number | null
  order_index?: number
  is_published?: boolean
}

export async function getTutorials(): Promise<TutorialsResponse> {
  const { data } = await apiClient.get<TutorialsResponse>('/auth/tutorials/')
  return data
}

export async function createTutorial(payload: TutorialWritePayload): Promise<TutorialVideo> {
  const { data } = await apiClient.post<TutorialVideo>('/auth/tutorials/', payload)
  return data
}

export async function updateTutorial(videoId: string, payload: Partial<TutorialWritePayload>): Promise<TutorialVideo> {
  const { data } = await apiClient.patch<TutorialVideo>(`/auth/tutorials/${videoId}/`, payload)
  return data
}

export async function deleteTutorial(videoId: string): Promise<void> {
  await apiClient.delete(`/auth/tutorials/${videoId}/`)
}

export async function updateTutorialProgress(videoId: string, completed: boolean): Promise<void> {
  await apiClient.post(`/auth/tutorials/${videoId}/progress/`, { completed })
}
