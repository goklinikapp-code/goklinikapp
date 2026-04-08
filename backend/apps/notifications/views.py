from __future__ import annotations

import logging

from django.db import transaction
from django.db.models import Count, Q
from rest_framework import generics, permissions, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.users.models import GoKlinikUser

from .models import (
    Notification,
    NotificationLog,
    NotificationTemplate,
    NotificationToken,
    NotificationWorkflow,
    ScheduledNotification,
)
from .serializers import (
    NotificationBroadcastSerializer,
    NotificationLogSerializer,
    NotificationRecipientSerializer,
    NotificationSerializer,
    NotificationTemplateSerializer,
    NotificationTokenSerializer,
    NotificationWorkflowSerializer,
    ScheduledNotificationSerializer,
)
from .services import NotificationAutomationService, NotificationService

logger = logging.getLogger(__name__)


class NotificationPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


class NotificationListAPIView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = NotificationPagination

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user).order_by("-created_at")


class NotificationReadAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, notification_id):
        notification = Notification.objects.filter(id=notification_id, recipient=request.user).first()
        if not notification:
            return Response({"detail": "Notification not found."}, status=status.HTTP_404_NOT_FOUND)

        if not notification.is_read:
            notification.is_read = True
            notification.save(update_fields=["is_read"])
        return Response(NotificationSerializer(notification).data, status=status.HTTP_200_OK)


class NotificationReadAllAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def put(self, request):
        unread = Notification.objects.filter(recipient=request.user, is_read=False)
        count = unread.count()
        unread.update(is_read=True)
        return Response({"updated_count": count}, status=status.HTTP_200_OK)


class NotificationClearAllAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request):
        queryset = Notification.objects.filter(recipient=request.user)
        deleted_count, _ = queryset.delete()
        return Response({"deleted_count": deleted_count}, status=status.HTTP_200_OK)


class NotificationUnreadCountAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        unread_count = Notification.objects.filter(recipient=request.user, is_read=False).count()
        return Response({"unread_count": unread_count}, status=status.HTTP_200_OK)


class RegisterTokenAPIView(generics.CreateAPIView):
    serializer_class = NotificationTokenSerializer
    permission_classes = [permissions.IsAuthenticated]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        token, created = NotificationToken.objects.update_or_create(
            user=request.user,
            device_token=serializer.validated_data["device_token"],
            defaults={
                "platform": serializer.validated_data["platform"],
                "is_active": serializer.validated_data.get("is_active", True),
            },
        )

        response_status = status.HTTP_201_CREATED if created else status.HTTP_200_OK
        return Response(NotificationTokenSerializer(token).data, status=response_status)


class BroadcastNotificationAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)
        if not user.tenant_id:
            return Response(
                {"detail": "Clinic tenant not found."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = NotificationBroadcastSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = serializer.validated_data

        try:
            if payload.get("target_mode") == "patient":
                recipients_qs = GoKlinikUser.objects.filter(
                    id=payload["patient_id"],
                    tenant_id=user.tenant_id,
                    role=GoKlinikUser.RoleChoices.PATIENT,
                    is_active=True,
                    notification_tokens__is_active=True,
                ).distinct()
            else:
                recipients_qs = NotificationService.resolve_recipients_for_segment(
                    tenant_id=user.tenant_id,
                    segment=payload["segment"],
                    specialty_id=payload.get("specialty_id"),
                    require_active_tokens=True,
                )
            recipients = list(recipients_qs)
            if not recipients:
                no_recipient_detail = "No recipients with active push token for selected segment."
                if payload.get("target_mode") == "patient":
                    no_recipient_detail = "Selected patient has no active push token."
                return Response(
                    {
                        "detail": no_recipient_detail,
                        "campaign_status": "no_recipients",
                        "segment": payload["segment"],
                        "total_recipients": 0,
                        "sent": 0,
                        "error": 0,
                        "skipped": 0,
                        "rate_limited": 0,
                    },
                    status=status.HTTP_200_OK,
                )

            if payload.get("template_code"):
                title_template, body_template = NotificationService.get_template_content(
                    code=payload["template_code"],
                    fallback_title=payload.get("title") or "Mensagem da clínica",
                    fallback_body=payload.get("body") or "{{message}}",
                    tenant_id=user.tenant_id,
                )
            else:
                title_template = payload.get("title") or "Mensagem da clínica"
                body_template = payload.get("body") or ""

            campaign_context = payload.get("template_context", {})
            if "message" not in campaign_context and payload.get("body"):
                campaign_context["message"] = payload["body"]

            with transaction.atomic():
                summary = NotificationService.send_push_campaign(
                    recipients=recipients,
                    title_template=title_template,
                    body_template=body_template,
                    context=campaign_context,
                    segment=payload["segment"],
                    event_code="manual_push_campaign",
                    data_extra={
                        **payload.get("data_extra", {}),
                        "sender_id": str(user.id),
                        "segment": payload["segment"],
                    },
                    create_in_app_notification=True,
                )

            if summary["error"] > 0 and summary["sent"] > 0:
                campaign_status = "partial"
            elif summary["error"] > 0:
                campaign_status = "error"
            else:
                campaign_status = "success"

            return Response(
                {
                    "detail": "Push campaign processed.",
                    "campaign_status": campaign_status,
                    "segment": payload["segment"],
                    **summary,
                },
                status=status.HTTP_200_OK,
            )
        except Exception as exc:  # noqa: BLE001
            logger.exception(
                "Manual push broadcast failed user=%s tenant=%s segment=%s",
                user.id,
                user.tenant_id,
                payload.get("segment"),
            )
            return Response(
                {
                    "detail": "Push campaign failed.",
                    "code": "push_campaign_error",
                    "campaign_status": "error",
                    "segment": payload.get("segment", ""),
                    "error": str(exc),
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )


class NotificationLogListAPIView(generics.ListAPIView):
    serializer_class = NotificationLogSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = NotificationPagination

    def get(self, request, *args, **kwargs):
        if request.user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)
        return super().get(request, *args, **kwargs)

    def delete(self, request, *args, **kwargs):
        if request.user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)
        if not request.user.tenant_id:
            return Response(
                {"detail": "Clinic tenant not found."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        queryset = self.get_queryset()
        scope = (request.query_params.get("scope") or "errors").strip().lower()
        if scope == "errors":
            queryset = queryset.filter(status=NotificationLog.StatusChoices.ERROR)

        deleted_count, _ = queryset.delete()
        return Response(
            {"deleted_count": deleted_count, "scope": scope},
            status=status.HTTP_200_OK,
        )

    def get_queryset(self):
        request = self.request
        if not request.user.tenant_id:
            return NotificationLog.objects.none()
        queryset = NotificationLog.objects.select_related("user").filter(
            tenant_id=request.user.tenant_id,
        )

        status_filter = (request.query_params.get("status") or "").strip()
        if status_filter:
            queryset = queryset.filter(status=status_filter)

        segment_filter = (request.query_params.get("segment") or "").strip()
        if segment_filter:
            queryset = queryset.filter(segment=segment_filter)

        event_filter = (request.query_params.get("event_code") or "").strip()
        if event_filter:
            queryset = queryset.filter(event_code=event_filter)

        return queryset.order_by("-created_at")


class NotificationRecipientSearchAPIView(generics.ListAPIView):
    serializer_class = NotificationRecipientSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = NotificationPagination

    def get(self, request, *args, **kwargs):
        if request.user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)
        return super().get(request, *args, **kwargs)

    def get_queryset(self):
        request = self.request
        user = request.user
        if not user.tenant_id:
            return GoKlinikUser.objects.none()

        query = (request.query_params.get("q") or "").strip()

        queryset = GoKlinikUser.objects.filter(
            tenant_id=user.tenant_id,
            role=GoKlinikUser.RoleChoices.PATIENT,
            is_active=True,
        )
        if query:
            queryset = queryset.filter(
                Q(first_name__icontains=query)
                | Q(last_name__icontains=query)
                | Q(email__icontains=query)
                | Q(phone__icontains=query)
            )

        return queryset.annotate(
            active_push_tokens=Count(
                "notification_tokens",
                filter=Q(notification_tokens__is_active=True),
                distinct=True,
            )
        ).order_by("first_name", "last_name", "email")

    def list(self, request, *args, **kwargs):
        queryset = self.filter_queryset(self.get_queryset())
        page = self.paginate_queryset(queryset)
        rows = page if page is not None else queryset

        payload = [
            {
                "id": item.id,
                "full_name": item.full_name,
                "email": item.email,
                "phone": item.phone or "",
                "active_push_tokens": int(getattr(item, "active_push_tokens", 0) or 0),
                "has_active_push_token": bool(getattr(item, "active_push_tokens", 0)),
            }
            for item in rows
        ]

        serializer = self.get_serializer(payload, many=True)
        if page is not None:
            return self.get_paginated_response(serializer.data)
        return Response(serializer.data, status=status.HTTP_200_OK)


class NotificationTemplateListCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @staticmethod
    def _ensure_clinic_master(request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)
        if not user.tenant_id:
            return Response(
                {"detail": "Clinic tenant not found."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return None

    def get(self, request):
        permission_error = self._ensure_clinic_master(request)
        if permission_error:
            return permission_error

        include_inactive = (request.query_params.get("include_inactive") or "").strip().lower() in {
            "1",
            "true",
            "yes",
        }
        queryset = NotificationTemplate.objects.filter(
            tenant_id=request.user.tenant_id,
        ).order_by("code")
        if not include_inactive:
            queryset = queryset.filter(is_active=True)

        return Response(
            NotificationTemplateSerializer(queryset, many=True).data,
            status=status.HTTP_200_OK,
        )

    def post(self, request):
        permission_error = self._ensure_clinic_master(request)
        if permission_error:
            return permission_error

        serializer = NotificationTemplateSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        template = serializer.save(
            tenant_id=request.user.tenant_id,
            created_by=request.user,
        )
        return Response(
            NotificationTemplateSerializer(template).data,
            status=status.HTTP_201_CREATED,
        )


class NotificationTemplateDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @staticmethod
    def _get_template_or_403(request, template_id):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return None, Response(status=status.HTTP_403_FORBIDDEN)
        template = NotificationTemplate.objects.filter(
            id=template_id,
            tenant_id=user.tenant_id,
        ).first()
        if not template:
            return None, Response(
                {"detail": "Template not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        return template, None

    def patch(self, request, template_id):
        template, error_response = self._get_template_or_403(request, template_id)
        if error_response:
            return error_response

        serializer = NotificationTemplateSerializer(
            template,
            data=request.data,
            partial=True,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)


class WorkflowListAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @staticmethod
    def _ensure_clinic_master(request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)
        if not user.tenant_id:
            return Response(
                {"detail": "Clinic tenant not found."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return None

    def get(self, request):
        permission_error = self._ensure_clinic_master(request)
        if permission_error:
            return permission_error

        NotificationAutomationService.ensure_default_workflows_for_tenant(request.user.tenant_id)
        workflows = NotificationWorkflow.objects.filter(
            tenant_id=request.user.tenant_id,
        ).order_by("name")
        return Response(
            NotificationWorkflowSerializer(workflows, many=True).data,
            status=status.HTTP_200_OK,
        )

    def post(self, request):
        permission_error = self._ensure_clinic_master(request)
        if permission_error:
            return permission_error

        serializer = NotificationWorkflowSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        workflow = serializer.save(
            tenant_id=request.user.tenant_id,
            created_by=request.user,
        )
        return Response(
            NotificationWorkflowSerializer(workflow).data,
            status=status.HTTP_201_CREATED,
        )


class WorkflowDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @staticmethod
    def _get_workflow_or_403(request, workflow_id):
        if request.user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return None, Response(status=status.HTTP_403_FORBIDDEN)
        workflow = NotificationWorkflow.objects.filter(
            id=workflow_id,
            tenant_id=request.user.tenant_id,
        ).first()
        if not workflow:
            return None, Response(
                {"detail": "Workflow not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        return workflow, None

    def patch(self, request, workflow_id):
        workflow, error_response = self._get_workflow_or_403(request, workflow_id)
        if error_response:
            return error_response
        serializer = NotificationWorkflowSerializer(
            workflow,
            data=request.data,
            partial=True,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)

    def put(self, request, workflow_id):
        workflow, error_response = self._get_workflow_or_403(request, workflow_id)
        if error_response:
            return error_response
        serializer = NotificationWorkflowSerializer(
            workflow,
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)


class ScheduledNotificationListCreateAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)

        scheduled_items = ScheduledNotification.objects.select_related("template").filter(
            tenant_id=user.tenant_id,
        ).order_by("-created_at")[:50]
        return Response(
            ScheduledNotificationSerializer(scheduled_items, many=True).data,
            status=status.HTTP_200_OK,
        )

    def post(self, request):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)
        if not user.tenant_id:
            return Response(
                {"detail": "Clinic tenant not found."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = ScheduledNotificationSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        payload = serializer.validated_data
        scheduled = NotificationAutomationService.create_scheduled_notification(
            created_by=user,
            run_at=payload["run_at"],
            segment=payload["segment"],
            title=payload.get("title", ""),
            body=payload.get("body", ""),
            template=payload.get("template"),
            template_context=payload.get("template_context", {}),
            data_extra=payload.get("data_extra", {}),
        )
        return Response(
            ScheduledNotificationSerializer(scheduled).data,
            status=status.HTTP_201_CREATED,
        )


class ScheduledNotificationDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, scheduled_notification_id):
        user = request.user
        if user.role != GoKlinikUser.RoleChoices.CLINIC_MASTER:
            return Response(status=status.HTTP_403_FORBIDDEN)

        scheduled = ScheduledNotification.objects.filter(
            id=scheduled_notification_id,
            tenant_id=user.tenant_id,
        ).first()
        if not scheduled:
            return Response(
                {"detail": "Scheduled notification not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        next_status = (request.data.get("status") or "").strip().lower()
        if next_status != ScheduledNotification.StatusChoices.CANCELED:
            return Response(
                {"detail": "Only cancellation is supported on this endpoint."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if scheduled.status in {
            ScheduledNotification.StatusChoices.COMPLETED,
            ScheduledNotification.StatusChoices.ERROR,
        }:
            return Response(
                {"detail": "Unable to cancel a processed scheduled notification."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        scheduled.status = ScheduledNotification.StatusChoices.CANCELED
        scheduled.save(update_fields=["status", "updated_at"])
        return Response(
            ScheduledNotificationSerializer(scheduled).data,
            status=status.HTTP_200_OK,
        )
