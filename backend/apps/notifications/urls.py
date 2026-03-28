from django.urls import path

from .views import (
    BroadcastNotificationAPIView,
    NotificationListAPIView,
    NotificationReadAPIView,
    NotificationReadAllAPIView,
    NotificationUnreadCountAPIView,
    RegisterTokenAPIView,
    WorkflowListAPIView,
)

urlpatterns = [
    path("", NotificationListAPIView.as_view(), name="notifications-list"),
    path("register-token/", RegisterTokenAPIView.as_view(), name="notifications-register-token"),
    path("read-all/", NotificationReadAllAPIView.as_view(), name="notifications-read-all"),
    path("unread-count/", NotificationUnreadCountAPIView.as_view(), name="notifications-unread-count"),
    path("<uuid:notification_id>/read/", NotificationReadAPIView.as_view(), name="notifications-read"),
    path("admin/broadcast/", BroadcastNotificationAPIView.as_view(), name="notifications-admin-broadcast"),
    path("workflows/", WorkflowListAPIView.as_view(), name="notifications-workflows"),
]
