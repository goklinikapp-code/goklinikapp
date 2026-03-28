from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import ChatRoomViewSet, PatientAIChatAPIView

router = DefaultRouter()
router.register(r"rooms", ChatRoomViewSet, basename="chat-rooms")

urlpatterns = [
    path("ai/messages/", PatientAIChatAPIView.as_view(), name="chat-ai-messages"),
    *router.urls,
]
