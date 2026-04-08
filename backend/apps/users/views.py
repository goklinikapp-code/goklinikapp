import logging
from pathlib import Path

from django.contrib.admin.models import LogEntry
from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import OpenApiResponse, extend_schema, inline_serializer
from rest_framework import permissions, serializers, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.notifications.services import NotificationService
from services.storage_paths import build_storage_path
from services.supabase_storage import SupabaseStorageError, upload_file

from .models import GoKlinikUser, TutorialProgress, TutorialVideo
from .serializers import (
    ActivityLogSerializer,
    ChangePasswordSerializer,
    ForgotPasswordSerializer,
    GoKlinikUserSerializer,
    InviteUserSerializer,
    LoginSerializer,
    RegisterPatientSerializer,
    SupabaseImageUploadSerializer,
    TutorialProgressUpdateSerializer,
    TutorialVideoSerializer,
    TutorialVideoWriteSerializer,
    TeamMemberDetailSerializer,
    TeamMemberSerializer,
    TeamMemberUpdateSerializer,
)

AUTH_RESPONSE_SERIALIZER = inline_serializer(
    name="AuthTokensResponseSerializer",
    fields={
        "access_token": serializers.CharField(),
        "refresh_token": serializers.CharField(),
        "user": GoKlinikUserSerializer(),
    },
)

DETAIL_RESPONSE_SERIALIZER = inline_serializer(
    name="DetailResponseSerializer",
    fields={"detail": serializers.CharField()},
)

logger = logging.getLogger(__name__)

IMAGE_EXTENSION_CONTENT_TYPES = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
    "heic": "image/heic",
    "heif": "image/heif",
    "gif": "image/gif",
    "bmp": "image/bmp",
    "tif": "image/tiff",
    "tiff": "image/tiff",
}


def _resolve_image_content_type(upload) -> tuple[str, bool]:
    raw_content_type = (getattr(upload, "content_type", "") or "").lower().strip()
    if raw_content_type.startswith("image/"):
        return raw_content_type, True

    extension = Path(str(getattr(upload, "name", "") or "")).suffix.lower().lstrip(".")
    inferred = IMAGE_EXTENSION_CONTENT_TYPES.get(extension, "")
    if inferred:
        return inferred, True

    return raw_content_type, False


class RegisterAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    @extend_schema(
        request=RegisterPatientSerializer,
        responses={
            status.HTTP_201_CREATED: AUTH_RESPONSE_SERIALIZER,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
        },
    )
    def post(self, request, *args, **kwargs):
        serializer = RegisterPatientSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        self._notify_new_patient_registered(patient=user)
        refresh = RefreshToken.for_user(user)

        return Response(
            {
                "access_token": str(refresh.access_token),
                "refresh_token": str(refresh),
                "user": GoKlinikUserSerializer(
                    user,
                    context={"request": request},
                ).data,
            },
            status=status.HTTP_201_CREATED,
        )

    def _notify_new_patient_registered(self, *, patient: GoKlinikUser) -> None:
        if not patient.tenant_id:
            return
        title = "Novo paciente cadastrado"
        body = f"{patient.full_name} acabou de criar conta no aplicativo."
        try:
            NotificationService.notify_clinic_masters_in_app(
                tenant_id=patient.tenant_id,
                title=title,
                body=body,
                related_object_id=patient.id,
            )
        except Exception:  # noqa: BLE001
            logger.exception(
                "Unable to notify clinic masters about new patient registration patient=%s tenant=%s",
                patient.id,
                patient.tenant_id,
            )


class LoginAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    @extend_schema(
        request=LoginSerializer,
        responses={
            status.HTTP_200_OK: AUTH_RESPONSE_SERIALIZER,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Invalid credentials."),
        },
    )
    def post(self, request, *args, **kwargs):
        serializer = LoginSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data["user"]

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access_token": str(refresh.access_token),
                "refresh_token": str(refresh),
                "user": GoKlinikUserSerializer(
                    user,
                    context={"request": request},
                ).data,
            }
        )


class ForgotPasswordAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    @extend_schema(
        request=ForgotPasswordSerializer,
        responses={status.HTTP_200_OK: DETAIL_RESPONSE_SERIALIZER},
    )
    def post(self, request, *args, **kwargs):
        serializer = ForgotPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(
            {"detail": "If the account exists, password reset instructions were sent."},
            status=status.HTTP_200_OK,
        )


class ChangePasswordAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(
        request=ChangePasswordSerializer,
        responses={
            status.HTTP_200_OK: DETAIL_RESPONSE_SERIALIZER,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required."),
        },
    )
    def post(self, request, *args, **kwargs):
        serializer = ChangePasswordSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response({"detail": "Password changed successfully."}, status=status.HTTP_200_OK)


class CurrentUserAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(
        responses={
            status.HTTP_200_OK: GoKlinikUserSerializer,
            status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required."),
        },
    )
    def get(self, request, *args, **kwargs):
        return Response(
            GoKlinikUserSerializer(
                request.user,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )


class CurrentUserAvatarUploadAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    @extend_schema(
        responses={
            status.HTTP_200_OK: GoKlinikUserSerializer,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Invalid file."),
            status.HTTP_502_BAD_GATEWAY: OpenApiResponse(description="Storage provider unavailable."),
            status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required."),
        },
    )
    def post(self, request, *args, **kwargs):
        avatar_file = request.FILES.get("avatar")
        if avatar_file is None:
            return Response(
                {"detail": "Avatar file is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        content_type, is_image = _resolve_image_content_type(avatar_file)
        if not is_image:
            return Response(
                {"detail": "Invalid file type."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        avatar_file.content_type = content_type

        tenant_id = str(request.user.tenant_id or "shared")
        storage_path = build_storage_path(
            tenant_id,
            "patients",
            request.user.id,
            "avatars",
            upload=avatar_file,
        )
        try:
            avatar_url = upload_file(avatar_file, storage_path)
        except SupabaseStorageError as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        request.user.avatar_url = avatar_url
        request.user.save(update_fields=["avatar_url"])

        return Response(
            GoKlinikUserSerializer(
                request.user,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )


class ImageAssetUploadAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    @extend_schema(
        request=SupabaseImageUploadSerializer,
        responses={
            status.HTTP_201_CREATED: OpenApiResponse(description="Image uploaded successfully."),
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_502_BAD_GATEWAY: OpenApiResponse(description="Storage provider unavailable."),
            status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required."),
        },
    )
    def post(self, request, *args, **kwargs):
        serializer = SupabaseImageUploadSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        try:
            payload = serializer.save()
        except SupabaseStorageError as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_502_BAD_GATEWAY,
            )
        return Response(payload, status=status.HTTP_201_CREATED)


class TeamMembersAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(
        responses={
            status.HTTP_200_OK: TeamMemberSerializer(many=True),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Forbidden for this role."),
        }
    )
    def get(self, request, *args, **kwargs):
        user = request.user
        if user.role not in {
            GoKlinikUser.RoleChoices.SUPER_ADMIN,
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
            GoKlinikUser.RoleChoices.SURGEON,
            GoKlinikUser.RoleChoices.SECRETARY,
        }:
            return Response(status=status.HTTP_403_FORBIDDEN)

        queryset = GoKlinikUser.objects.exclude(role=GoKlinikUser.RoleChoices.PATIENT)
        if user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            queryset = queryset.filter(tenant_id=user.tenant_id)

        queryset = queryset.order_by("first_name", "last_name", "email")
        return Response(
            TeamMemberSerializer(
                queryset,
                many=True,
                context={"request": request},
            ).data
        )


class ActivityLogAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(
        responses={
            status.HTTP_200_OK: ActivityLogSerializer(many=True),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Forbidden for this role."),
        }
    )
    def get(self, request, *args, **kwargs):
        user = request.user
        if user.role not in {
            GoKlinikUser.RoleChoices.SUPER_ADMIN,
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
            GoKlinikUser.RoleChoices.SURGEON,
        }:
            return Response(status=status.HTTP_403_FORBIDDEN)

        users_qs = GoKlinikUser.objects.all()
        if user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            users_qs = users_qs.filter(tenant_id=user.tenant_id)

        logs = (
            LogEntry.objects.filter(user_id__in=users_qs.values_list("id", flat=True))
            .select_related("user")
            .order_by("-action_time")[:100]
        )

        payload = [
            {
                "id": str(item.id),
                "created_at": item.action_time,
                "user": item.user.full_name if item.user_id else "Unknown",
                "action": item.change_message or item.get_action_flag_display(),
                "ip": "",
            }
            for item in logs
        ]
        return Response(ActivityLogSerializer(payload, many=True).data)


class InviteUserAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(
        request=InviteUserSerializer,
        responses={
            status.HTTP_201_CREATED: TeamMemberSerializer,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Forbidden for this role."),
        },
    )
    def post(self, request, *args, **kwargs):
        user = request.user
        if user.role not in {
            GoKlinikUser.RoleChoices.SUPER_ADMIN,
            GoKlinikUser.RoleChoices.CLINIC_MASTER,
        }:
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = InviteUserSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        invited = serializer.save()

        return Response(
            TeamMemberSerializer(
                invited,
                context={"request": request},
            ).data,
            status=status.HTTP_201_CREATED,
        )


class TeamMemberDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    VIEW_ALLOWED_ROLES = {
        GoKlinikUser.RoleChoices.SUPER_ADMIN,
        GoKlinikUser.RoleChoices.CLINIC_MASTER,
        GoKlinikUser.RoleChoices.SURGEON,
        GoKlinikUser.RoleChoices.SECRETARY,
    }
    MANAGE_ALLOWED_ROLES = {
        GoKlinikUser.RoleChoices.SUPER_ADMIN,
        GoKlinikUser.RoleChoices.CLINIC_MASTER,
    }

    def _scoped_queryset(self, request):
        queryset = GoKlinikUser.objects.exclude(role=GoKlinikUser.RoleChoices.PATIENT)
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            queryset = queryset.filter(tenant_id=request.user.tenant_id)
        return queryset

    def _get_member_or_404(self, request, member_id):
        return get_object_or_404(self._scoped_queryset(request), id=member_id)

    @extend_schema(
        responses={
            status.HTTP_200_OK: TeamMemberDetailSerializer,
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Forbidden for this role."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="User not found."),
        }
    )
    def get(self, request, member_id, *args, **kwargs):
        if request.user.role not in self.VIEW_ALLOWED_ROLES:
            return Response(status=status.HTTP_403_FORBIDDEN)

        member = self._get_member_or_404(request, member_id)
        return Response(
            TeamMemberDetailSerializer(
                member,
                context={"request": request},
            ).data
        )

    @extend_schema(
        request=TeamMemberUpdateSerializer,
        responses={
            status.HTTP_200_OK: TeamMemberDetailSerializer,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Forbidden for this role."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="User not found."),
        },
    )
    def patch(self, request, member_id, *args, **kwargs):
        if request.user.role not in self.MANAGE_ALLOWED_ROLES:
            return Response(status=status.HTTP_403_FORBIDDEN)

        member = self._get_member_or_404(request, member_id)
        if member.role == GoKlinikUser.RoleChoices.SUPER_ADMIN and request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = TeamMemberUpdateSerializer(
            member,
            data=request.data,
            partial=True,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)

        if (
            serializer.validated_data.get("is_active") is False
            and str(member.id) == str(request.user.id)
        ):
            return Response(
                {"detail": "You cannot deactivate your own account."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if (
            serializer.validated_data.get("role")
            and serializer.validated_data["role"] == GoKlinikUser.RoleChoices.SUPER_ADMIN
            and request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN
        ):
            return Response(
                {"detail": "Only super admin can assign this role."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        updated = serializer.save()
        return Response(
            TeamMemberDetailSerializer(
                updated,
                context={"request": request},
            ).data,
            status=status.HTTP_200_OK,
        )

    @extend_schema(
        responses={
            status.HTTP_204_NO_CONTENT: OpenApiResponse(description="Deleted."),
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Forbidden for this role."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="User not found."),
        }
    )
    def delete(self, request, member_id, *args, **kwargs):
        if request.user.role not in self.MANAGE_ALLOWED_ROLES:
            return Response(status=status.HTTP_403_FORBIDDEN)

        member = self._get_member_or_404(request, member_id)

        if str(member.id) == str(request.user.id):
            return Response(
                {"detail": "You cannot delete your own account."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if member.role == GoKlinikUser.RoleChoices.SUPER_ADMIN and request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        if member.role == GoKlinikUser.RoleChoices.CLINIC_MASTER and member.tenant_id:
            remaining_masters = GoKlinikUser.objects.filter(
                tenant_id=member.tenant_id,
                role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
            ).exclude(id=member.id).count()
            if remaining_masters == 0:
                return Response(
                    {"detail": "Cannot delete the last clinic master of this clinic."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        member.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class TutorialsAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    ALLOWED_ROLES = {
        GoKlinikUser.RoleChoices.SUPER_ADMIN,
        GoKlinikUser.RoleChoices.CLINIC_MASTER,
    }

    def _queryset_for_user(self, user):
        queryset = TutorialVideo.objects.all().order_by("order_index", "created_at")
        if user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            queryset = queryset.filter(is_published=True)
        return queryset

    @extend_schema(
        responses={
            status.HTTP_200_OK: OpenApiResponse(description="Tutorial videos and progress summary."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Forbidden for this role."),
            status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required."),
        }
    )
    def get(self, request, *args, **kwargs):
        if request.user.role not in self.ALLOWED_ROLES:
            return Response(status=status.HTTP_403_FORBIDDEN)

        videos = list(self._queryset_for_user(request.user))
        progress_rows = TutorialProgress.objects.filter(
            user=request.user,
            video_id__in=[video.id for video in videos],
        )
        progress_map = {str(progress.video_id): progress for progress in progress_rows}

        serialized = TutorialVideoSerializer(
            videos,
            many=True,
            context={"progress_map": progress_map},
        ).data

        total_videos = len(videos)
        completed_videos = 0
        for video in videos:
            progress = progress_map.get(str(video.id))
            if progress and progress.completed:
                completed_videos += 1
        remaining_videos = max(total_videos - completed_videos, 0)
        completion_percent = round((completed_videos / total_videos) * 100, 2) if total_videos else 0.0

        return Response(
            {
                "videos": serialized,
                "summary": {
                    "total_videos": total_videos,
                    "completed_videos": completed_videos,
                    "remaining_videos": remaining_videos,
                    "completion_percent": completion_percent,
                },
            },
            status=status.HTTP_200_OK,
        )

    @extend_schema(
        request=TutorialVideoWriteSerializer,
        responses={
            status.HTTP_201_CREATED: TutorialVideoSerializer,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can create tutorials."),
            status.HTTP_401_UNAUTHORIZED: OpenApiResponse(description="Authentication required."),
        },
    )
    def post(self, request, *args, **kwargs):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = TutorialVideoWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        video = serializer.save(created_by=request.user)

        return Response(
            TutorialVideoSerializer(video, context={"progress_map": {}}).data,
            status=status.HTTP_201_CREATED,
        )


class TutorialDetailAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    ALLOWED_ROLES = {
        GoKlinikUser.RoleChoices.SUPER_ADMIN,
        GoKlinikUser.RoleChoices.CLINIC_MASTER,
    }

    def _get_video(self, video_id):
        return get_object_or_404(TutorialVideo, id=video_id)

    @extend_schema(
        responses={
            status.HTTP_200_OK: TutorialVideoSerializer,
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Forbidden for this role."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Video not found."),
        },
    )
    def get(self, request, video_id, *args, **kwargs):
        if request.user.role not in self.ALLOWED_ROLES:
            return Response(status=status.HTTP_403_FORBIDDEN)

        video = self._get_video(video_id)
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN and not video.is_published:
            return Response(status=status.HTTP_404_NOT_FOUND)

        progress = TutorialProgress.objects.filter(user=request.user, video=video).first()
        progress_map = {str(video.id): progress} if progress else {}
        return Response(TutorialVideoSerializer(video, context={"progress_map": progress_map}).data)

    @extend_schema(
        request=TutorialVideoWriteSerializer,
        responses={
            status.HTTP_200_OK: TutorialVideoSerializer,
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can update tutorials."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Video not found."),
        },
    )
    def patch(self, request, video_id, *args, **kwargs):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        video = self._get_video(video_id)
        serializer = TutorialVideoWriteSerializer(video, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        updated = serializer.save()
        return Response(TutorialVideoSerializer(updated, context={"progress_map": {}}).data)

    @extend_schema(
        responses={
            status.HTTP_204_NO_CONTENT: OpenApiResponse(description="Deleted."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Only super admin can delete tutorials."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Video not found."),
        },
    )
    def delete(self, request, video_id, *args, **kwargs):
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            return Response(status=status.HTTP_403_FORBIDDEN)

        video = self._get_video(video_id)
        video.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class TutorialProgressAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    ALLOWED_ROLES = {
        GoKlinikUser.RoleChoices.SUPER_ADMIN,
        GoKlinikUser.RoleChoices.CLINIC_MASTER,
    }

    @extend_schema(
        request=TutorialProgressUpdateSerializer,
        responses={
            status.HTTP_200_OK: OpenApiResponse(description="Tutorial progress updated."),
            status.HTTP_400_BAD_REQUEST: OpenApiResponse(description="Validation error."),
            status.HTTP_403_FORBIDDEN: OpenApiResponse(description="Forbidden for this role."),
            status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Video not found."),
        },
    )
    def post(self, request, video_id, *args, **kwargs):
        if request.user.role not in self.ALLOWED_ROLES:
            return Response(status=status.HTTP_403_FORBIDDEN)

        video = get_object_or_404(TutorialVideo, id=video_id)
        if request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN and not video.is_published:
            return Response(status=status.HTTP_404_NOT_FOUND)

        serializer = TutorialProgressUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        completed = serializer.validated_data["completed"]

        progress, _ = TutorialProgress.objects.get_or_create(
            user=request.user,
            video=video,
        )
        progress.completed = completed
        progress.completed_at = timezone.now() if completed else None
        progress.save(update_fields=["completed", "completed_at", "updated_at"])

        return Response(
            {
                "video_id": str(video.id),
                "completed": progress.completed,
                "completed_at": progress.completed_at,
            },
            status=status.HTTP_200_OK,
        )
