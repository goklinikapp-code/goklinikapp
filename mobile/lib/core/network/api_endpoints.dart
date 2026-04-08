class ApiEndpoints {
  static const authLogin = '/api/auth/login/';
  static const authRegister = '/api/auth/register/';
  static const authRefresh = '/api/auth/refresh/';
  static const authMe = '/api/auth/me/';
  static const authMeAvatar = '/api/auth/me/avatar/';
  static const publicSignupClinics = '/api/public/tenants/clinics/';
  static String publicReferralLookup(String code) => '/api/referral/$code/';

  static const postOpMyJourney = '/api/post-op/my-journey/';
  static const postOperatoryMyJourney = '/api/post-operatory/my-journey/';
  static String postOpCompleteChecklist(String id) =>
      '/api/post-op/checklist/$id/complete/';
  static String postOperatoryChecklist(String id) =>
      '/api/post-operatory/checklist/$id/';
  static const postOperatoryCheckin = '/api/post-operatory/checkin/';
  static const postOpPhotos = '/api/post-op/photos/';
  static const postOperatoryPhoto = '/api/post-operatory/photo/';
  static String postOpPhotosByJourney(String journeyId) =>
      '/api/post-op/photos/$journeyId/';
  static String postOpCareCenter(String journeyId) =>
      '/api/post-op/care-center/$journeyId/';
  static const postOpUrgentRequests = '/api/post-op/urgent-requests/';
  static const urgentTickets = '/api/urgent-tickets/';
  static String urgentTicketDetail(String ticketId) =>
      '/api/urgent-tickets/$ticketId/';
  static const preOperatory = '/api/pre-operatory';
  static const preOperatoryMe = '/api/pre-operatory/me';
  static String preOperatoryDetail(String preOperatoryId) =>
      '/api/pre-operatory/$preOperatoryId';
  static String preOperatoryFileDetail(String fileId) =>
      '/api/pre-operatory/files/$fileId';

  static const chatRooms = '/api/chat/rooms/';
  static String chatRoomMessages(String roomId) =>
      '/api/chat/rooms/$roomId/messages/';
  static String chatRoomRead(String roomId) => '/api/chat/rooms/$roomId/read/';
  static const chatAiMessages = '/api/chat/ai/messages/';
  static const chatAiTypingStatus = '/api/chat/ai/typing-status/';

  static const notifications = '/api/notifications/';
  static String notificationsRead(String notificationId) =>
      '/api/notifications/$notificationId/read/';
  static const notificationsReadAll = '/api/notifications/read-all/';
  static const notificationsClearAll = '/api/notifications/clear-all/';
  static const notificationsUnreadCount = '/api/notifications/unread-count/';
  static const notificationsRegisterToken =
      '/api/notifications/register-token/';

  static const financialMyTransactions = '/api/financial/my-transactions/';
  static const financialMyPackages = '/api/financial/my-packages/';
  static const referralsMyReferrals = '/api/referrals/my-referrals/';

  static const medicalRecordMyRecord = '/api/medical-records/my-record/';
  static String medicalRecordDocuments(String patientId) =>
      '/api/medical-records/$patientId/documents/';

  static const appointments = '/api/appointments/';
  static String appointmentDetail(String appointmentId) =>
      '/api/appointments/$appointmentId/';
  static const appointmentsAvailableSlots =
      '/api/appointments/available-slots/';
  static const appointmentsAvailableProfessionals =
      '/api/appointments/available-professionals/';

  static const travelPlansMyPlan = '/api/travel-plans/my-plan/';
  static String travelPlansConfirmTransfer(String transferId) =>
      '/api/travel-plans/transfers/$transferId/confirm/';

  static String publicTenantBranding(String slug) =>
      '/api/public/tenants/$slug/branding/';
}
