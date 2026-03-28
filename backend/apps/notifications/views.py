from __future__ import annotations

from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.users.models import GoKlinikUser

from .models import Notification, NotificationToken
from .serializers import (
    NotificationBroadcastSerializer,
    NotificationSerializer,
    NotificationTokenSerializer,
)


class NotificationPagination(PageNumberPagination):
    page_size = 20


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

        serializer = NotificationBroadcastSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = serializer.validated_data

        recipients = GoKlinikUser.objects.filter(
            role=GoKlinikUser.RoleChoices.PATIENT,
            tenant_id=user.tenant_id,
            is_active=True,
        )
        if not payload.get("send_to_all", False) and payload.get("specialty_id"):
            recipients = recipients.filter(patient__specialty_id=payload["specialty_id"])

        now = timezone.now()
        notifications = [
            Notification(
                tenant_id=user.tenant_id,
                recipient=recipient,
                title=payload["title"],
                body=payload["body"],
                notification_type=Notification.NotificationTypeChoices.PROMOTION,
                sent_at=now,
            )
            for recipient in recipients
        ]
        with transaction.atomic():
            Notification.objects.bulk_create(notifications)

        return Response(
            {"detail": "Broadcast created.", "recipients": len(notifications)},
            status=status.HTTP_200_OK,
        )


class WorkflowListAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        if request.user.role == GoKlinikUser.RoleChoices.PATIENT:
            return Response(status=status.HTTP_403_FORBIDDEN)

        workflows = [
            {
                "id": "wf-1",
                "title": "Lembrete de Consulta 24h antes",
                "trigger": "24h antes do agendamento",
                "action": "Enviar push e WhatsApp",
                "is_active": True,
            },
            {
                "id": "wf-2",
                "title": "Follow-up Pós-op D+7",
                "trigger": "Ao completar 7 dias da cirurgia",
                "action": "Enviar checklist e orientações",
                "is_active": True,
            },
            {
                "id": "wf-3",
                "title": "Reativação de Pacientes Inativos",
                "trigger": "Sem consulta há 180 dias",
                "action": "Disparar campanha segmentada",
                "is_active": False,
            },
        ]
        return Response(workflows, status=status.HTTP_200_OK)
