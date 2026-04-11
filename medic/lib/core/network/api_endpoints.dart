class ApiEndpoints {
  static String publicTenantBranding(String slug) =>
      '/api/public/tenants/$slug/branding/';

  static const authLogin = '/api/auth/login/';
  static const authRegister = '/api/auth/register/';
  static const authRefresh = '/api/auth/refresh/';
  static const authMe = '/api/auth/me/';
  static const authMeAvatar = '/api/auth/me/avatar/';
  static const authChangePassword = '/api/auth/change-password/';
  static const authTeam = '/api/auth/team/';

  static const patients = '/api/patients/';
  static const patientsMyPatients = '/api/patients/my-patients/';
  static String patientDetail(String patientId) => '/api/patients/$patientId/';
  static String patientTimeline(String patientId) =>
      '/api/patients/$patientId/timeline/';
  static String patientAssignDoctor(String patientId) =>
      '/api/patients/$patientId/assign-doctor/';
  static String preOperatoryByPatient(String patientId) =>
      '/api/pre-operatory/patient/$patientId/';
  static const preOperatory = '/api/pre-operatory/';
  static String preOperatoryDetail(String preOperatoryId) =>
      '/api/pre-operatory/$preOperatoryId/';

  static const postOpMyJourney = '/api/post-op/my-journey/';
  static String postOperatoryByPatient(String patientId) =>
      '/api/post-operatory/$patientId/';
  static String postOpCompleteChecklist(String id) =>
      '/api/post-op/checklist/$id/complete/';
  static const postOpAdminJourneys = '/api/post-op/admin/journeys/';
  static const postOpPhotos = '/api/post-op/photos/';
  static String postOpPhotosByJourney(String journeyId) =>
      '/api/post-op/photos/$journeyId/';
  static String postOpCareCenter(String journeyId) =>
      '/api/post-op/care-center/$journeyId/';
  static const postOpUrgentRequests = '/api/post-op/urgent-requests/';
  static String postOpUrgentRequestReply(String requestId) =>
      '/api/post-op/urgent-requests/$requestId/reply/';
  static const urgentTickets = '/api/urgent-tickets/';
  static String urgentTicketDetail(String ticketId) =>
      '/api/urgent-tickets/$ticketId/';

  static const chatRooms = '/api/chat/rooms/';
  static String chatRoomMessages(String roomId) =>
      '/api/chat/rooms/$roomId/messages/';
  static String chatRoomRead(String roomId) => '/api/chat/rooms/$roomId/read/';

  static const notifications = '/api/notifications/';
  static String notificationsRead(String notificationId) =>
      '/api/notifications/$notificationId/read/';
  static const notificationsReadAll = '/api/notifications/read-all/';
  static const notificationsUnreadCount = '/api/notifications/unread-count/';
  static const notificationsRegisterToken =
      '/api/notifications/register-token/';

  static const financialMyTransactions = '/api/financial/my-transactions/';
  static const financialMyPackages = '/api/financial/my-packages/';
  static const referralsMyReferrals = '/api/referrals/my-referrals/';

  static const medicalRecordMyRecord = '/api/medical-records/my-record/';
  static String medicalRecordDocuments(String patientId) =>
      '/api/medical-records/$patientId/documents/';
  static String medicalRecordProntuarioMedications(String patientId) =>
      '/api/medical-records/$patientId/prontuario/medications/';
  static String medicalRecordProntuarioMedicationDetail(
    String patientId,
    String medicationId,
  ) =>
      '/api/medical-records/$patientId/prontuario/medications/$medicationId/';
  static String medicalRecordProntuarioProcedures(String patientId) =>
      '/api/medical-records/$patientId/prontuario/procedures/';
  static String medicalRecordProntuarioProcedureDetail(
    String patientId,
    String procedureId,
  ) =>
      '/api/medical-records/$patientId/prontuario/procedures/$procedureId/';
  static String medicalRecordProntuarioProcedureImageDetail(
    String patientId,
    String procedureId,
    String imageId,
  ) =>
      '/api/medical-records/$patientId/prontuario/procedures/$procedureId/images/$imageId/';
  static String medicalRecordProntuarioDocuments(String patientId) =>
      '/api/medical-records/$patientId/prontuario/documents/';
  static String medicalRecordProntuarioDocumentDetail(
    String patientId,
    String documentId,
  ) =>
      '/api/medical-records/$patientId/prontuario/documents/$documentId/';

  static const appointments = '/api/appointments/';
  static String appointmentDetail(String appointmentId) =>
      '/api/appointments/$appointmentId/';
  static const appointmentsAvailableSlots =
      '/api/appointments/available-slots/';
  static const appointmentsAvailabilityRules =
      '/api/appointments/availability-rules/';
  static const appointmentsBlockedPeriods =
      '/api/appointments/blocked-periods/';
}
