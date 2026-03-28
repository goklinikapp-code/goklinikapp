from django.urls import path

from .views import (
    AdminJourneysAPIView,
    CareCenterAPIView,
    CompleteChecklistItemAPIView,
    EvolutionPhotoCreateAPIView,
    EvolutionPhotoListAPIView,
    MyJourneyAPIView,
    UrgentMedicalRequestListCreateAPIView,
    UrgentMedicalRequestReplyAPIView,
)

urlpatterns = [
    path("my-journey/", MyJourneyAPIView.as_view(), name="postop-my-journey"),
    path("checklist/<uuid:checklist_id>/complete/", CompleteChecklistItemAPIView.as_view(), name="postop-checklist-complete"),
    path("photos/", EvolutionPhotoCreateAPIView.as_view(), name="postop-photo-create"),
    path("photos/<uuid:journey_id>/", EvolutionPhotoListAPIView.as_view(), name="postop-photo-list"),
    path("admin/journeys/", AdminJourneysAPIView.as_view(), name="postop-admin-journeys"),
    path("care-center/<uuid:journey_id>/", CareCenterAPIView.as_view(), name="postop-care-center"),
    path("urgent-requests/", UrgentMedicalRequestListCreateAPIView.as_view(), name="postop-urgent-requests"),
    path(
        "urgent-requests/<uuid:request_id>/reply/",
        UrgentMedicalRequestReplyAPIView.as_view(),
        name="postop-urgent-requests-reply",
    ),
]
