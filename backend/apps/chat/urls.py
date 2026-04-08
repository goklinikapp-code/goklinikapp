from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import (
    ChatAIAdminConversationListAPIView,
    ChatAIAdminConversationMessagesAPIView,
    ChatAIAdminPatientModeAPIView,
    ChatAIAdminSettingsAPIView,
    ChatAIAdminTypingAPIView,
    ChatRoomViewSet,
    PatientAIChatAPIView,
    PatientAITypingStatusAPIView,
)

router = DefaultRouter()
router.register(r"rooms", ChatRoomViewSet, basename="chat-rooms")

urlpatterns = [
    path("ai/messages/", PatientAIChatAPIView.as_view(), name="chat-ai-messages"),
    path("ai/typing-status/", PatientAITypingStatusAPIView.as_view(), name="chat-ai-typing-status"),
    path("admin/ai/settings/", ChatAIAdminSettingsAPIView.as_view(), name="chat-admin-ai-settings"),
    path(
        "admin/ai/conversations/",
        ChatAIAdminConversationListAPIView.as_view(),
        name="chat-admin-ai-conversations",
    ),
    path(
        "admin/ai/patients/<uuid:patient_id>/messages/",
        ChatAIAdminConversationMessagesAPIView.as_view(),
        name="chat-admin-ai-conversation-messages",
    ),
    path(
        "admin/ai/patients/<uuid:patient_id>/mode/",
        ChatAIAdminPatientModeAPIView.as_view(),
        name="chat-admin-ai-patient-mode",
    ),
    path(
        "admin/ai/patients/<uuid:patient_id>/typing/",
        ChatAIAdminTypingAPIView.as_view(),
        name="chat-admin-ai-patient-typing",
    ),
    *router.urls,
]
