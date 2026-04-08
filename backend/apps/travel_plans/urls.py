from django.urls import path

from .views import (
    MyTravelPlanAPIView,
    TravelPlanAdminPatientsAPIView,
    TravelPlanDetailAPIView,
    TravelPlanFlightUpsertAPIView,
    TravelPlanHotelUpsertAPIView,
    TravelPlanListCreateAPIView,
    TravelPlanTransferConfirmAPIView,
    TravelPlanTransferCreateAPIView,
    TravelPlanTransferDetailAPIView,
)

urlpatterns = [
    path("my-plan/", MyTravelPlanAPIView.as_view(), name="travel-plans-my-plan"),
    path("admin/patients/", TravelPlanAdminPatientsAPIView.as_view(), name="travel-plans-admin-patients"),
    path("", TravelPlanListCreateAPIView.as_view(), name="travel-plans-list-create"),
    path("<uuid:travel_plan_id>/", TravelPlanDetailAPIView.as_view(), name="travel-plans-detail"),
    path(
        "<uuid:travel_plan_id>/flights/",
        TravelPlanFlightUpsertAPIView.as_view(),
        name="travel-plans-flight-upsert",
    ),
    path(
        "<uuid:travel_plan_id>/hotel/",
        TravelPlanHotelUpsertAPIView.as_view(),
        name="travel-plans-hotel-upsert",
    ),
    path(
        "<uuid:travel_plan_id>/transfers/",
        TravelPlanTransferCreateAPIView.as_view(),
        name="travel-plans-transfer-create",
    ),
    path(
        "transfers/<uuid:transfer_id>/",
        TravelPlanTransferDetailAPIView.as_view(),
        name="travel-plans-transfer-detail",
    ),
    path(
        "transfers/<uuid:transfer_id>/confirm/",
        TravelPlanTransferConfirmAPIView.as_view(),
        name="travel-plans-transfer-confirm",
    ),
]
