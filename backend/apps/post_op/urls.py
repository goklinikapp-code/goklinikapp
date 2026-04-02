from django.urls import path

from .views import (
    AdminJourneysAPIView,
    CareCenterAPIView,
    CompleteChecklistItemAPIView,
    EvolutionPhotoCreateAPIView,
    EvolutionPhotoListAPIView,
    MyJourneyAPIView,
    PostOperatoryAdminDetailAPIView,
    PostOperatoryAdminListAPIView,
    PostOperatoryCheckinCreateAPIView,
    PostOperatoryChecklistUpdateAPIView,
    PostOperatoryPhotoCreateAPIView,
    UrgentMedicalRequestListCreateAPIView,
    UrgentMedicalRequestReplyAPIView,
    UrgentTicketListCreateAPIView,
    UrgentTicketStatusUpdateAPIView,
)

urlpatterns = [
    path("", PostOperatoryAdminListAPIView.as_view(), name="postoperatory-admin-list"),
    path("my-journey/", MyJourneyAPIView.as_view(), name="postop-my-journey"),
    path(
        "checklist/<uuid:checklist_id>/complete/",
        CompleteChecklistItemAPIView.as_view(),
        name="postop-checklist-complete",
    ),
    path(
        "checklist/<uuid:checklist_id>/",
        PostOperatoryChecklistUpdateAPIView.as_view(),
        name="postoperatory-checklist-update",
    ),
    path("checkin/", PostOperatoryCheckinCreateAPIView.as_view(), name="postoperatory-checkin-create"),
    path("photos/", EvolutionPhotoCreateAPIView.as_view(), name="postop-photo-create"),
    path("photo/", PostOperatoryPhotoCreateAPIView.as_view(), name="postoperatory-photo-create"),
    path("photos/<uuid:journey_id>/", EvolutionPhotoListAPIView.as_view(), name="postop-photo-list"),
    path("admin/journeys/", AdminJourneysAPIView.as_view(), name="postop-admin-journeys"),
    path("care-center/<uuid:journey_id>/", CareCenterAPIView.as_view(), name="postop-care-center"),
    path("urgent-tickets/", UrgentTicketListCreateAPIView.as_view(), name="urgent-ticket-list-create"),
    path(
        "urgent-tickets/<uuid:ticket_id>/",
        UrgentTicketStatusUpdateAPIView.as_view(),
        name="urgent-ticket-status-update",
    ),
    path("urgent-requests/", UrgentMedicalRequestListCreateAPIView.as_view(), name="postop-urgent-requests"),
    path("<uuid:patient_id>/", PostOperatoryAdminDetailAPIView.as_view(), name="postoperatory-admin-detail"),
    path(
        "urgent-requests/<uuid:request_id>/reply/",
        UrgentMedicalRequestReplyAPIView.as_view(),
        name="postop-urgent-requests-reply",
    ),
]
