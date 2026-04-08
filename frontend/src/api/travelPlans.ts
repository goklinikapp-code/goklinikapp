import { apiClient } from '@/lib/axios'

export type FlightDirection = 'arrival' | 'departure'
export type TransferStatus = 'scheduled' | 'confirmed' | 'completed' | 'cancelled'

export interface FlightInfo {
  id: string
  direction: FlightDirection
  flight_number: string
  flight_date: string
  flight_time: string
  airport: string
  airline?: string
  observations?: string
  created_at?: string
}

export interface HotelInfo {
  id: string
  hotel_name: string
  address: string
  checkin_date: string
  checkin_time: string
  checkout_date: string
  checkout_time: string
  room_number?: string
  hotel_phone?: string
  location_link?: string
  observations?: string
}

export interface TransferItem {
  id: string
  title: string
  transfer_date: string
  transfer_time: string
  origin: string
  destination: string
  observations?: string
  status: TransferStatus
  reminder_sent?: boolean
  confirmed_by_patient: boolean
  confirmed_at?: string | null
  display_order: number
  created_at?: string
}

export interface TravelPlan {
  id: string
  tenant: string
  patient: string
  patient_name: string
  passport_number?: string
  created_by?: string
  arrival_flight: FlightInfo | null
  departure_flight: FlightInfo | null
  hotel: HotelInfo | null
  transfers: TransferItem[]
  created_at: string
  updated_at: string
}

export interface TravelPlanAdminPatientItem {
  patient_id: string
  patient_name: string
  travel_plan_id: string | null
  arrival_date: string | null
  hotel_name: string
  transfers_count: number
  next_transfer_status: string
}

export interface CreateTravelPlanPayload {
  patient_id: string
}

export interface UpdateTravelPlanPayload {
  passport_number?: string
}

export interface FlightUpsertPayload {
  direction: FlightDirection
  flight_number: string
  flight_date: string
  flight_time: string
  airport: string
  airline?: string
  observations?: string
}

export interface HotelUpsertPayload {
  hotel_name: string
  address: string
  checkin_date: string
  checkin_time: string
  checkout_date: string
  checkout_time: string
  room_number?: string
  hotel_phone?: string
  location_link?: string
  observations?: string
}

export interface TransferUpsertPayload {
  title: string
  transfer_date: string
  transfer_time: string
  origin: string
  destination: string
  observations?: string
  status: TransferStatus
  display_order: number
}

export async function getTravelPlanAdminPatients(): Promise<TravelPlanAdminPatientItem[]> {
  const { data } = await apiClient.get<TravelPlanAdminPatientItem[]>('/travel-plans/admin/patients/')
  return Array.isArray(data) ? data : []
}

export async function getTravelPlanById(travelPlanId: string): Promise<TravelPlan> {
  const { data } = await apiClient.get<TravelPlan>(`/travel-plans/${travelPlanId}/`)
  return data
}

export async function createTravelPlan(payload: CreateTravelPlanPayload): Promise<TravelPlan> {
  const { data } = await apiClient.post<TravelPlan>('/travel-plans/', payload)
  return data
}

export async function updateTravelPlan(
  travelPlanId: string,
  payload: UpdateTravelPlanPayload,
): Promise<TravelPlan> {
  const { data } = await apiClient.put<TravelPlan>(`/travel-plans/${travelPlanId}/`, payload)
  return data
}

export async function upsertFlight(
  travelPlanId: string,
  payload: FlightUpsertPayload,
): Promise<FlightInfo> {
  const { data } = await apiClient.post<FlightInfo>(`/travel-plans/${travelPlanId}/flights/`, payload)
  return data
}

export async function upsertHotel(
  travelPlanId: string,
  payload: HotelUpsertPayload,
): Promise<HotelInfo> {
  const { data } = await apiClient.post<HotelInfo>(`/travel-plans/${travelPlanId}/hotel/`, payload)
  return data
}

export async function createTransfer(
  travelPlanId: string,
  payload: TransferUpsertPayload,
): Promise<TransferItem> {
  const { data } = await apiClient.post<TransferItem>(`/travel-plans/${travelPlanId}/transfers/`, payload)
  return data
}

export async function updateTransfer(
  transferId: string,
  payload: Partial<TransferUpsertPayload>,
): Promise<TransferItem> {
  const { data } = await apiClient.put<TransferItem>(`/travel-plans/transfers/${transferId}/`, payload)
  return data
}

export async function deleteTransfer(transferId: string): Promise<void> {
  await apiClient.delete(`/travel-plans/transfers/${transferId}/`)
}
