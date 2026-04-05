from django.urls import path

from .views import (
    BroadcastNotificationAPIView,
    NotificationLogListAPIView,
    NotificationListAPIView,
    NotificationReadAPIView,
    NotificationReadAllAPIView,
    NotificationRecipientSearchAPIView,
    NotificationTemplateDetailAPIView,
    NotificationTemplateListCreateAPIView,
    NotificationUnreadCountAPIView,
    RegisterTokenAPIView,
    ScheduledNotificationDetailAPIView,
    ScheduledNotificationListCreateAPIView,
    WorkflowDetailAPIView,
    WorkflowListAPIView,
)

urlpatterns = [
    path("", NotificationListAPIView.as_view(), name="notifications-list"),
    path("register-token/", RegisterTokenAPIView.as_view(), name="notifications-register-token"),
    path("read-all/", NotificationReadAllAPIView.as_view(), name="notifications-read-all"),
    path("unread-count/", NotificationUnreadCountAPIView.as_view(), name="notifications-unread-count"),
    path("<uuid:notification_id>/read/", NotificationReadAPIView.as_view(), name="notifications-read"),
    path("admin/broadcast/", BroadcastNotificationAPIView.as_view(), name="notifications-admin-broadcast"),
    path("admin/logs/", NotificationLogListAPIView.as_view(), name="notifications-admin-logs"),
    path(
        "admin/recipients/search/",
        NotificationRecipientSearchAPIView.as_view(),
        name="notifications-admin-recipient-search",
    ),
    path("templates/", NotificationTemplateListCreateAPIView.as_view(), name="notifications-templates"),
    path(
        "templates/<uuid:template_id>/",
        NotificationTemplateDetailAPIView.as_view(),
        name="notifications-template-detail",
    ),
    path("workflows/", WorkflowListAPIView.as_view(), name="notifications-workflows"),
    path("workflows/<uuid:workflow_id>/", WorkflowDetailAPIView.as_view(), name="notifications-workflow-detail"),
    path(
        "admin/scheduled/",
        ScheduledNotificationListCreateAPIView.as_view(),
        name="notifications-admin-scheduled",
    ),
    path(
        "admin/scheduled/<uuid:scheduled_notification_id>/",
        ScheduledNotificationDetailAPIView.as_view(),
        name="notifications-admin-scheduled-detail",
    ),
]
