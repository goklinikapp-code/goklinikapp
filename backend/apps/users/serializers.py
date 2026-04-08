from __future__ import annotations
from datetime import timedelta
from urllib.parse import parse_qsl, urlencode, urlparse

from django.conf import settings
from django.contrib.auth import authenticate
from django.core.mail import send_mail
from django.db import transaction
from django.db.models import Q
from django.db import models
from django.utils.crypto import get_random_string
from django.utils import timezone
from django.utils.text import slugify
from django.contrib.auth.hashers import make_password
from rest_framework.exceptions import PermissionDenied
from rest_framework import serializers

from config.media_urls import AbsoluteMediaUrlsSerializerMixin

from apps.tenants.models import Tenant
from services.storage_paths import build_storage_path
from services.supabase_storage import upload_file

from .access import (
    ACCESS_PERMISSION_KEYS,
    resolve_access_permissions_for_role,
)
from .invite_email import (
    InviteEmailError,
    normalize_invite_email_language,
    send_team_invite_email,
)
from .models import (
    GoKlinikUser,
    SaaSAISettings,
    SaaSClinicSignupRequest,
    SaaSSeller,
    TutorialProgress,
    TutorialVideo,
    UploadedImageAsset,
    extract_youtube_video_id,
)
from .saas_email import send_saas_invite_email, send_signup_code_email
from .supabase_client import supabase_send_reset_password, supabase_sign_in, supabase_sign_up

STAFF_UPLOAD_ROLES = {
    GoKlinikUser.RoleChoices.CLINIC_MASTER,
    GoKlinikUser.RoleChoices.SECRETARY,
    GoKlinikUser.RoleChoices.SURGEON,
    GoKlinikUser.RoleChoices.NURSE,
}


class TenantEmbeddedSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    class Meta:
        model = Tenant
        fields = (
            "id",
            "name",
            "slug",
            "plan",
            "primary_color",
            "secondary_color",
            "accent_color",
            "logo_url",
            "favicon_url",
        )


class GoKlinikUserSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    tenant = TenantEmbeddedSerializer(read_only=True)
    full_name = serializers.CharField(read_only=True)

    class Meta:
        model = GoKlinikUser
        fields = (
            "id",
            "email",
            "full_name",
            "first_name",
            "last_name",
            "role",
            "referral_code",
            "phone",
            "cpf",
            "date_of_birth",
            "avatar_url",
            "bio",
            "crm_number",
            "years_experience",
            "is_visible_in_app",
            "access_permissions",
            "tenant",
            "is_active",
            "date_joined",
        )
        read_only_fields = (
            "id",
            "role",
            "tenant",
            "referral_code",
            "is_active",
            "date_joined",
        )


class RegisterPatientSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=255)
    clinic_id = serializers.UUIDField(required=False, allow_null=True)
    cpf = serializers.CharField(max_length=20, required=False, allow_blank=True)
    email = serializers.EmailField()
    phone = serializers.CharField(max_length=30)
    date_of_birth = serializers.DateField(required=False, allow_null=True)
    password = serializers.CharField(write_only=True, min_length=8)
    referral_code = serializers.CharField(max_length=255, required=False, allow_blank=True)

    def validate_email(self, value):
        if GoKlinikUser.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value.lower()

    @staticmethod
    def _normalize_referral_code(referral_code: str | None) -> str:
        if not referral_code:
            return ""

        normalized = referral_code.strip()
        if "://" in normalized:
            parsed = urlparse(normalized)
            path_chunks = [chunk for chunk in parsed.path.split("/") if chunk]
            normalized = path_chunks[-1] if path_chunks else ""
        elif "/" in normalized:
            path_chunks = [chunk for chunk in normalized.split("/") if chunk]
            normalized = path_chunks[-1] if path_chunks else normalized

        return normalized.strip().upper()

    def _resolve_tenant(
        self,
        *,
        clinic_id=None,
        referrer: GoKlinikUser | None = None,
    ) -> Tenant:
        request = self.context["request"]
        if clinic_id:
            selected_tenant = Tenant.objects.filter(id=clinic_id, is_active=True).first()
            if not selected_tenant:
                raise serializers.ValidationError({"clinic_id": "Selected clinic is invalid."})
            if referrer and referrer.tenant_id != selected_tenant.id:
                raise serializers.ValidationError(
                    {"referral_code": "Referral code does not belong to the selected clinic."}
                )
            return selected_tenant

        if referrer and referrer.tenant_id and referrer.tenant and referrer.tenant.is_active:
            return referrer.tenant

        tenant_slug = request.headers.get("X-Tenant-Slug")
        if tenant_slug:
            tenant_from_header = Tenant.objects.filter(slug=tenant_slug, is_active=True).first()
            if tenant_from_header:
                return tenant_from_header

        raise serializers.ValidationError({"clinic_id": "Clinic is required."})

    def _resolve_referrer(self, referral_code: str | None) -> GoKlinikUser | None:
        normalized = self._normalize_referral_code(referral_code)
        if not normalized:
            return None

        referrer = GoKlinikUser.objects.select_related("tenant").filter(
            referral_code=normalized,
            is_active=True,
            tenant__is_active=True,
        ).exclude(
            role=GoKlinikUser.RoleChoices.SUPER_ADMIN,
        ).first()
        if not referrer or not referrer.tenant_id:
            raise serializers.ValidationError({"referral_code": "Referral code is invalid."})
        return referrer

    def validate(self, attrs):
        referrer = self._resolve_referrer(attrs.get("referral_code", ""))
        tenant = self._resolve_tenant(
            clinic_id=attrs.get("clinic_id"),
            referrer=referrer,
        )
        attrs["_resolved_referrer"] = referrer
        attrs["_resolved_tenant"] = tenant
        return attrs

    def create(self, validated_data):
        from apps.patients.models import Patient
        from apps.referrals.models import Referral

        full_name = validated_data.pop("full_name").strip()
        validated_data.pop("referral_code", "")
        validated_data.pop("clinic_id", None)
        referrer = validated_data.pop("_resolved_referrer", None)
        tenant = validated_data.pop("_resolved_tenant", None)
        parts = full_name.split()
        first_name = parts[0] if parts else ""
        last_name = " ".join(parts[1:]) if len(parts) > 1 else ""
        if not tenant:
            raise serializers.ValidationError({"clinic_id": "Clinic is required."})

        patient = Patient.objects.create_user(
            email=validated_data["email"],
            password=validated_data["password"],
            first_name=first_name,
            last_name=last_name,
            tenant=tenant,
            role=GoKlinikUser.RoleChoices.PATIENT,
            cpf=validated_data.get("cpf", ""),
            phone=validated_data["phone"],
            date_of_birth=validated_data.get("date_of_birth"),
            referred_by=referrer,
            is_active=True,
        )

        if referrer:
            Referral.objects.create(
                tenant=tenant,
                referrer=referrer,
                referred=patient,
                status=Referral.StatusChoices.PENDING,
            )

        supabase_sign_up(
            email=patient.email,
            password=validated_data["password"],
            metadata={
                "tenant_slug": tenant.slug,
                "role": GoKlinikUser.RoleChoices.PATIENT,
                "full_name": patient.full_name,
            },
        )
        return patient


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField(required=False)
    identifier = serializers.CharField(required=False)
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        request = self.context.get("request")
        identifier = (attrs.get("identifier") or attrs.get("email") or "").strip().lower()
        password = attrs.get("password")
        email = identifier

        if "@" not in identifier:
            user_by_cpf = GoKlinikUser.objects.filter(cpf=identifier).first()
            email = user_by_cpf.email.lower() if user_by_cpf else ""

        if not email:
            raise serializers.ValidationError("Invalid credentials.")

        user = authenticate(request=request, email=email, password=password)
        if not user:
            raise serializers.ValidationError("Invalid credentials.")

        supabase_ok = supabase_sign_in(email, password)
        if settings.SUPABASE_AUTH_STRICT and not supabase_ok:
            raise serializers.ValidationError("Supabase authentication failed.")

        attrs["user"] = user
        return attrs


class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def save(self):
        email = self.validated_data["email"].lower()
        sent = supabase_send_reset_password(email)
        if not sent:
            send_mail(
                subject="Go Klinik password reset request",
                message=(
                    "We received a password reset request. "
                    "Please contact your clinic admin if this was not you."
                ),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=True,
            )
        return {"email": email, "sent_with_supabase": sent}


class SupabaseImageUploadSerializer(serializers.Serializer):
    class TargetChoices(models.TextChoices):
        PATIENT = "patient", "Patient"
        CLINIC = "clinic", "Clinic"

    target = serializers.ChoiceField(choices=TargetChoices.choices)
    patient_id = serializers.UUIDField(required=False, allow_null=True)
    file = serializers.ImageField(write_only=True)
    image_url = serializers.URLField(read_only=True)
    storage_path = serializers.CharField(read_only=True)
    asset_id = serializers.UUIDField(read_only=True)

    def validate(self, attrs):
        request = self.context["request"]
        user = request.user
        target = attrs["target"]
        patient_id = attrs.get("patient_id")

        if not user.tenant_id:
            raise serializers.ValidationError({"detail": "Tenant context is required for uploads."})

        if target == self.TargetChoices.CLINIC:
            if user.role not in STAFF_UPLOAD_ROLES:
                raise PermissionDenied("Only clinic staff can upload clinic images.")
            attrs["_tenant"] = user.tenant
            attrs["patient_id"] = None
            return attrs

        if user.role == GoKlinikUser.RoleChoices.PATIENT:
            if patient_id and str(patient_id) != str(user.id):
                raise PermissionDenied("Patient can upload only their own image.")
            patient_id = user.id
        elif user.role in STAFF_UPLOAD_ROLES:
            if not patient_id:
                raise serializers.ValidationError(
                    {"patient_id": "patient_id is required when target is patient."}
                )
        else:
            raise PermissionDenied("You do not have permission to upload patient images.")

        from apps.patients.models import Patient

        patient = (
            Patient.objects.select_related("tenant")
            .filter(id=patient_id, tenant_id=user.tenant_id)
            .first()
        )
        if not patient:
            raise serializers.ValidationError(
                {"patient_id": "Patient not found for your clinic."}
            )

        attrs["patient_id"] = patient.id
        attrs["_patient"] = patient
        return attrs

    def _build_storage_path(self, *, tenant_id: str, target: str, patient_id=None, upload=None) -> str:
        if target == self.TargetChoices.PATIENT and patient_id:
            return build_storage_path(
                tenant_id,
                "patients",
                patient_id,
                "avatars",
                upload=upload,
            )
        return build_storage_path(
            tenant_id,
            "clinic",
            "assets",
            upload=upload,
        )

    def create(self, validated_data):
        request = self.context["request"]
        user = request.user
        target = validated_data["target"]
        upload = validated_data["file"]
        patient = validated_data.get("_patient")
        tenant = validated_data.get("_tenant") or user.tenant

        if tenant is None:
            raise serializers.ValidationError({"detail": "Tenant was not resolved for upload."})

        storage_path = self._build_storage_path(
            tenant_id=str(tenant.id),
            target=target,
            patient_id=getattr(patient, "id", None),
            upload=upload,
        )

        image_url = upload_file(upload, storage_path)

        if target == self.TargetChoices.PATIENT:
            patient.avatar_url = image_url
            patient.save(update_fields=["avatar_url"])
        else:
            tenant.logo_url = image_url
            tenant.save(update_fields=["logo_url", "updated_at"])

        asset = UploadedImageAsset.objects.create(
            tenant=tenant,
            patient=patient,
            target=target,
            image_url=image_url,
            storage_path=storage_path,
            uploaded_by=user,
        )

        return {
            "asset_id": asset.id,
            "target": target,
            "patient_id": str(patient.id) if patient else None,
            "image_url": image_url,
            "storage_path": storage_path,
        }


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)
    confirm_new_password = serializers.CharField(write_only=True, min_length=8)

    def validate(self, attrs):
        if attrs["new_password"] != attrs["confirm_new_password"]:
            raise serializers.ValidationError("New password and confirmation must match.")

        user = self.context["request"].user
        if not user.check_password(attrs["current_password"]):
            raise serializers.ValidationError("Current password is invalid.")
        return attrs

    def save(self, **kwargs):
        user = self.context["request"].user
        user.set_password(self.validated_data["new_password"])
        user.save(update_fields=["password"])
        return user


class TeamMemberSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    full_name = serializers.CharField(read_only=True)

    class Meta:
        model = GoKlinikUser
        fields = (
            "id",
            "email",
            "full_name",
            "role",
            "is_active",
            "avatar_url",
            "access_permissions",
        )


class TeamMemberDetailSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    full_name = serializers.CharField(read_only=True)

    class Meta:
        model = GoKlinikUser
        fields = (
            "id",
            "full_name",
            "first_name",
            "last_name",
            "email",
            "role",
            "is_active",
            "phone",
            "cpf",
            "date_of_birth",
            "avatar_url",
            "bio",
            "crm_number",
            "years_experience",
            "is_visible_in_app",
            "access_permissions",
            "date_joined",
        )
        read_only_fields = ("id", "date_joined")


class TutorialVideoSerializer(serializers.ModelSerializer):
    embed_url = serializers.CharField(read_only=True)
    progress_completed = serializers.SerializerMethodField()
    progress_completed_at = serializers.SerializerMethodField()

    class Meta:
        model = TutorialVideo
        fields = (
            "id",
            "title",
            "description",
            "youtube_url",
            "embed_url",
            "thumbnail_url",
            "duration_minutes",
            "order_index",
            "is_published",
            "created_at",
            "updated_at",
            "progress_completed",
            "progress_completed_at",
        )

    def _get_progress_entry(self, obj: TutorialVideo) -> TutorialProgress | None:
        progress_map = self.context.get("progress_map") or {}
        return progress_map.get(str(obj.id)) or progress_map.get(obj.id)

    def get_progress_completed(self, obj: TutorialVideo) -> bool:
        progress = self._get_progress_entry(obj)
        return bool(progress and progress.completed)

    def get_progress_completed_at(self, obj: TutorialVideo):
        progress = self._get_progress_entry(obj)
        return progress.completed_at if progress and progress.completed_at else None


class TutorialVideoWriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = TutorialVideo
        fields = (
            "title",
            "description",
            "youtube_url",
            "thumbnail_url",
            "duration_minutes",
            "order_index",
            "is_published",
        )

    def validate_title(self, value):
        clean_value = (value or "").strip()
        if len(clean_value) < 3:
            raise serializers.ValidationError("Title must have at least 3 characters.")
        return clean_value

    def validate_description(self, value):
        return (value or "").strip()

    def validate_youtube_url(self, value):
        if not extract_youtube_video_id(value):
            raise serializers.ValidationError("Provide a valid YouTube URL.")
        return value

    def validate_duration_minutes(self, value):
        if value is not None and value <= 0:
            raise serializers.ValidationError("Duration must be greater than zero.")
        return value

    def validate_order_index(self, value):
        if value <= 0:
            raise serializers.ValidationError("Order index must be greater than zero.")
        return value


class TutorialProgressUpdateSerializer(serializers.Serializer):
    completed = serializers.BooleanField()


class TeamMemberUpdateSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=255, required=False)
    email = serializers.EmailField(required=False)
    role = serializers.CharField(max_length=50, required=False)
    phone = serializers.CharField(max_length=30, required=False, allow_blank=True)
    cpf = serializers.CharField(max_length=14, required=False, allow_blank=True)
    date_of_birth = serializers.DateField(required=False, allow_null=True)
    avatar_url = serializers.URLField(required=False, allow_blank=True, max_length=2048)
    bio = serializers.CharField(required=False, allow_blank=True)
    crm_number = serializers.CharField(max_length=60, required=False, allow_blank=True)
    years_experience = serializers.IntegerField(required=False, allow_null=True, min_value=0)
    is_visible_in_app = serializers.BooleanField(required=False)
    is_active = serializers.BooleanField(required=False)
    access_permissions = serializers.ListField(
        child=serializers.CharField(max_length=40),
        required=False,
        allow_empty=True,
    )

    ROLE_MAP = {
        "master": GoKlinikUser.RoleChoices.CLINIC_MASTER,
        "clinic_master": GoKlinikUser.RoleChoices.CLINIC_MASTER,
        "surgeon": GoKlinikUser.RoleChoices.SURGEON,
        "secretary": GoKlinikUser.RoleChoices.SECRETARY,
        "nursing": GoKlinikUser.RoleChoices.NURSE,
        "nurse": GoKlinikUser.RoleChoices.NURSE,
        "super_admin": GoKlinikUser.RoleChoices.SUPER_ADMIN,
    }

    def validate_email(self, value):
        lowered = value.lower()
        instance = self.instance
        if GoKlinikUser.objects.filter(email__iexact=lowered).exclude(pk=instance.pk).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return lowered

    def validate_role(self, value):
        normalized = value.strip().lower().replace(" ", "_")
        mapped = self.ROLE_MAP.get(normalized)
        if not mapped:
            raise serializers.ValidationError("Unsupported role.")

        request = self.context["request"]
        if mapped == GoKlinikUser.RoleChoices.SUPER_ADMIN and request.user.role != GoKlinikUser.RoleChoices.SUPER_ADMIN:
            raise serializers.ValidationError("Only super admin can assign this role.")
        return mapped

    def validate_access_permissions(self, value):
        unknown = [item for item in value if (item or "").strip().lower() not in ACCESS_PERMISSION_KEYS]
        if unknown:
            raise serializers.ValidationError("Unsupported access permission.")
        return [(item or "").strip().lower() for item in value]

    def update(self, instance: GoKlinikUser, validated_data):
        full_name = validated_data.pop("full_name", None)
        role_was_updated = "role" in validated_data
        permissions_were_updated = "access_permissions" in validated_data
        role_after_update = validated_data.get("role", instance.role)
        requested_permissions = validated_data.pop("access_permissions", None)
        if full_name is not None:
            parts = full_name.strip().split()
            instance.first_name = parts[0] if parts else ""
            instance.last_name = " ".join(parts[1:]) if len(parts) > 1 else ""

        for field, value in validated_data.items():
            setattr(instance, field, value)

        if permissions_were_updated:
            instance.access_permissions = resolve_access_permissions_for_role(
                role_after_update,
                requested_permissions,
            )
        elif role_was_updated:
            instance.access_permissions = resolve_access_permissions_for_role(
                role_after_update,
                None,
            )

        instance.save()
        return instance


class SaaSAISettingsSerializer(serializers.ModelSerializer):
    api_key = serializers.CharField(write_only=True, required=False, allow_blank=True)
    api_key_masked = serializers.SerializerMethodField()
    has_api_key = serializers.SerializerMethodField()
    key_source = serializers.SerializerMethodField()

    class Meta:
        model = SaaSAISettings
        fields = (
            "api_key",
            "api_key_masked",
            "has_api_key",
            "key_source",
            "updated_at",
        )
        read_only_fields = ("api_key_masked", "has_api_key", "updated_at")

    def _effective_key(self, obj: SaaSAISettings) -> str:
        db_value = (obj.api_key or "").strip()
        if db_value:
            return db_value
        return (getattr(settings, "GROK_API_KEY", "") or "").strip()

    def get_api_key_masked(self, obj: SaaSAISettings) -> str:
        value = self._effective_key(obj)
        if not value:
            return ""
        if len(value) <= 8:
            return "•" * len(value)
        return f"{value[:4]}{'•' * (len(value) - 8)}{value[-4:]}"

    def get_has_api_key(self, obj: SaaSAISettings) -> bool:
        return bool(self._effective_key(obj))

    def get_key_source(self, obj: SaaSAISettings) -> str:
        return "panel" if (obj.api_key or "").strip() else "env"

    def update(self, instance: SaaSAISettings, validated_data):
        api_key = validated_data.get("api_key", None)
        if api_key is not None:
            instance.api_key = api_key.strip()
        instance.save()
        return instance


class ActivityLogSerializer(serializers.Serializer):
    id = serializers.CharField()
    created_at = serializers.DateTimeField()
    user = serializers.CharField()
    action = serializers.CharField()
    ip = serializers.CharField(allow_blank=True, allow_null=True)


class InviteUserSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=255)
    email = serializers.EmailField()
    role = serializers.CharField(max_length=50)
    access_permissions = serializers.ListField(
        child=serializers.CharField(max_length=40),
        required=False,
        allow_empty=True,
    )
    language = serializers.CharField(max_length=32, required=False, allow_blank=True, write_only=True)

    ROLE_MAP = {
        "master": GoKlinikUser.RoleChoices.CLINIC_MASTER,
        "clinic_master": GoKlinikUser.RoleChoices.CLINIC_MASTER,
        "surgeon": GoKlinikUser.RoleChoices.SURGEON,
        "secretary": GoKlinikUser.RoleChoices.SECRETARY,
        "nursing": GoKlinikUser.RoleChoices.NURSE,
        "nurse": GoKlinikUser.RoleChoices.NURSE,
    }

    def validate_email(self, value):
        lowered = value.lower()
        if GoKlinikUser.objects.filter(email__iexact=lowered).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return lowered

    def validate_role(self, value):
        mapped = self.ROLE_MAP.get(value.lower())
        if not mapped:
            raise serializers.ValidationError("Unsupported role.")
        return mapped

    def validate_language(self, value):
        return normalize_invite_email_language(value)

    def validate_access_permissions(self, value):
        unknown = [item for item in value if (item or "").strip().lower() not in ACCESS_PERMISSION_KEYS]
        if unknown:
            raise serializers.ValidationError("Unsupported access permission.")
        return [(item or "").strip().lower() for item in value]

    def create(self, validated_data):
        request = self.context["request"]
        inviter = request.user
        language = validated_data.pop("language", None)
        requested_permissions = validated_data.pop("access_permissions", None)
        if not language:
            language = normalize_invite_email_language(
                request.headers.get("X-Panel-Language") or request.headers.get("Accept-Language")
            )

        full_name = validated_data["full_name"].strip()
        parts = full_name.split()
        first_name = parts[0] if parts else ""
        last_name = " ".join(parts[1:]) if len(parts) > 1 else ""

        tenant_id = inviter.tenant_id
        if inviter.role == GoKlinikUser.RoleChoices.SUPER_ADMIN:
            tenant_id = tenant_id or GoKlinikUser.objects.filter(
                role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
                tenant__isnull=False,
            ).values_list("tenant_id", flat=True).first()

        temp_password = get_random_string(12)

        with transaction.atomic():
            user = GoKlinikUser.objects.create_user(
                email=validated_data["email"],
                password=temp_password,
                first_name=first_name,
                last_name=last_name,
                role=validated_data["role"],
                tenant_id=tenant_id,
                access_permissions=resolve_access_permissions_for_role(
                    validated_data["role"],
                    requested_permissions,
                ),
                is_staff=validated_data["role"] in {
                    GoKlinikUser.RoleChoices.CLINIC_MASTER,
                    GoKlinikUser.RoleChoices.SURGEON,
                    GoKlinikUser.RoleChoices.SECRETARY,
                    GoKlinikUser.RoleChoices.NURSE,
                },
                is_active=True,
            )

            try:
                send_team_invite_email(
                    invited_user=user,
                    inviter=inviter,
                    temporary_password=temp_password,
                    language=language,
                )
            except InviteEmailError as exc:
                raise serializers.ValidationError({"email": str(exc)})

        return user


def split_full_name(full_name: str) -> tuple[str, str]:
    parts = (full_name or "").strip().split()
    first_name = parts[0] if parts else ""
    last_name = " ".join(parts[1:]) if len(parts) > 1 else ""
    return first_name, last_name


def build_unique_tenant_slug(name: str, *, current_tenant_id=None) -> str:
    base_slug = slugify(name or "")[:70] or "clinic"
    candidate = base_slug
    counter = 2
    while Tenant.objects.filter(slug=candidate).exclude(id=current_tenant_id).exists():
        suffix = f"-{counter}"
        candidate = f"{base_slug[:80 - len(suffix)]}{suffix}"
        counter += 1
    return candidate


class SaaSClientListSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    name = serializers.CharField()
    slug = serializers.CharField()
    plan = serializers.CharField()
    is_active = serializers.BooleanField()
    created_at = serializers.DateTimeField()
    primary_contact_name = serializers.CharField(allow_blank=True)
    primary_contact_email = serializers.EmailField(allow_blank=True)
    primary_contact_phone = serializers.CharField(allow_blank=True)
    primary_contact_tax_number = serializers.CharField(allow_blank=True)
    patients_count = serializers.IntegerField()
    appointments_next_30_days = serializers.IntegerField()
    staff_count = serializers.IntegerField()
    clinic_addresses = serializers.ListField(child=serializers.CharField(), allow_empty=True)


class SaaSClientCreateSerializer(serializers.Serializer):
    class ModeChoices(models.TextChoices):
        DIRECT = "direct", "Direct"
        INVITE = "invite", "Invite"

    mode = serializers.ChoiceField(choices=ModeChoices.choices, default=ModeChoices.DIRECT)
    clinic_name = serializers.CharField(max_length=255)
    plan = serializers.ChoiceField(choices=Tenant.PlanChoices.choices, default=Tenant.PlanChoices.STARTER)
    clinic_addresses = serializers.ListField(
        child=serializers.CharField(max_length=255),
        required=False,
        allow_empty=True,
    )
    owner_full_name = serializers.CharField(max_length=255)
    owner_email = serializers.EmailField()
    owner_phone = serializers.CharField(max_length=30, required=False, allow_blank=True)
    owner_tax_number = serializers.CharField(max_length=20, required=False, allow_blank=True)
    password = serializers.CharField(min_length=8, required=False, allow_blank=True, write_only=True)
    seller_id = serializers.UUIDField(required=False, allow_null=True)
    language = serializers.CharField(max_length=32, required=False, allow_blank=True, write_only=True)

    def validate_owner_email(self, value):
        lowered = value.lower()
        if GoKlinikUser.objects.filter(email__iexact=lowered).exists():
            raise serializers.ValidationError("Já existe um usuário com este e-mail.")
        return lowered

    def validate(self, attrs):
        mode = attrs.get("mode")
        password = (attrs.get("password") or "").strip()
        if mode == self.ModeChoices.DIRECT and len(password) < 8:
            raise serializers.ValidationError({"password": "A senha deve ter no mínimo 8 caracteres."})
        if mode == self.ModeChoices.INVITE:
            attrs["password"] = ""

        seller_id = attrs.get("seller_id")
        attrs["seller"] = None
        if seller_id:
            seller = SaaSSeller.objects.filter(id=seller_id).first()
            if not seller:
                raise serializers.ValidationError({"seller_id": "Vendedor não encontrado."})
            attrs["seller"] = seller
        return attrs

    def create(self, validated_data):
        request = self.context["request"]
        language = normalize_invite_email_language(validated_data.pop("language", None))
        mode = validated_data.pop("mode")
        seller = validated_data.pop("seller", None)
        seller_id = validated_data.pop("seller_id", None)
        if seller_id:
            validated_data.pop("seller_id", None)

        clinic_name = validated_data["clinic_name"].strip()
        owner_full_name = validated_data["owner_full_name"].strip()
        owner_email = validated_data["owner_email"].lower()
        owner_phone = validated_data.get("owner_phone", "").strip()
        owner_tax_number = validated_data.get("owner_tax_number", "").strip()
        plan = validated_data["plan"]
        clinic_addresses = [
            address.strip()
            for address in validated_data.get("clinic_addresses", [])
            if address and address.strip()
        ]

        if mode == self.ModeChoices.INVITE:
            signup_request = SaaSClinicSignupRequest.objects.create(
                flow=SaaSClinicSignupRequest.FlowChoices.SAAS_INVITE,
                status=SaaSClinicSignupRequest.StatusChoices.PENDING,
                clinic_name=clinic_name,
                clinic_slug=build_unique_tenant_slug(clinic_name),
                plan=plan,
                owner_full_name=owner_full_name,
                owner_email=owner_email,
                owner_phone=owner_phone,
                owner_tax_number=owner_tax_number,
                verification_expires_at=timezone.now() + timedelta(days=7),
                seller=seller,
                created_by=request.user,
            )
            send_saas_invite_email(
                email=owner_email,
                full_name=owner_full_name,
                clinic_name=clinic_name,
                invite_token=str(signup_request.invite_token),
                language=language,
            )
            return {
                "mode": mode,
                "invite_request_id": str(signup_request.id),
                "invite_token": str(signup_request.invite_token),
            }

        tenant_slug = build_unique_tenant_slug(clinic_name)
        first_name, last_name = split_full_name(owner_full_name)
        with transaction.atomic():
            tenant = Tenant.objects.create(
                name=clinic_name,
                slug=tenant_slug,
                plan=plan,
                clinic_addresses=clinic_addresses,
                is_active=True,
            )
            owner = GoKlinikUser.objects.create_user(
                email=owner_email,
                password=validated_data.get("password"),
                first_name=first_name,
                last_name=last_name,
                role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
                tenant=tenant,
                cpf=owner_tax_number,
                phone=owner_phone,
                is_staff=True,
                is_active=True,
            )
            SaaSClinicSignupRequest.objects.create(
                flow=SaaSClinicSignupRequest.FlowChoices.SAAS_INVITE,
                status=SaaSClinicSignupRequest.StatusChoices.VERIFIED,
                clinic_name=clinic_name,
                clinic_slug=tenant_slug,
                plan=plan,
                owner_full_name=owner_full_name,
                owner_email=owner_email,
                owner_phone=owner_phone,
                owner_tax_number=owner_tax_number,
                tenant=tenant,
                seller=seller,
                created_by=request.user,
                accepted_at=timezone.now(),
            )
        return {
            "mode": mode,
            "tenant": tenant,
            "owner": owner,
        }


class SaaSClientUpdateSerializer(serializers.Serializer):
    clinic_name = serializers.CharField(max_length=255, required=False)
    plan = serializers.ChoiceField(choices=Tenant.PlanChoices.choices, required=False)
    clinic_addresses = serializers.ListField(
        child=serializers.CharField(max_length=255),
        required=False,
        allow_empty=True,
    )
    is_active = serializers.BooleanField(required=False)
    owner_full_name = serializers.CharField(max_length=255, required=False)
    owner_email = serializers.EmailField(required=False)
    owner_phone = serializers.CharField(max_length=30, required=False, allow_blank=True)
    owner_tax_number = serializers.CharField(max_length=20, required=False, allow_blank=True)
    password = serializers.CharField(min_length=8, required=False, write_only=True)

    def validate_owner_email(self, value):
        lowered = value.lower()
        owner = self.context.get("owner")
        if GoKlinikUser.objects.filter(email__iexact=lowered).exclude(id=getattr(owner, "id", None)).exists():
            raise serializers.ValidationError("Já existe um usuário com este e-mail.")
        return lowered

    def update_client(self, *, tenant: Tenant, owner: GoKlinikUser | None):
        data = self.validated_data

        if "clinic_name" in data:
            tenant.name = data["clinic_name"].strip()
            tenant.slug = build_unique_tenant_slug(tenant.name, current_tenant_id=tenant.id)
        if "plan" in data:
            tenant.plan = data["plan"]
        if "clinic_addresses" in data:
            tenant.clinic_addresses = [
                address.strip()
                for address in data["clinic_addresses"]
                if address and address.strip()
            ]
        if "is_active" in data:
            tenant.is_active = data["is_active"]
        tenant.save()

        if owner:
            if "owner_full_name" in data:
                first_name, last_name = split_full_name(data["owner_full_name"])
                owner.first_name = first_name
                owner.last_name = last_name
            if "owner_email" in data:
                owner.email = data["owner_email"]
            if "owner_phone" in data:
                owner.phone = data["owner_phone"]
            if "owner_tax_number" in data:
                owner.cpf = data["owner_tax_number"]
            if "password" in data and data["password"]:
                owner.set_password(data["password"])
            if "is_active" in data:
                owner.is_active = data["is_active"]
            owner.save()

        if "is_active" in data:
            GoKlinikUser.objects.filter(tenant_id=tenant.id).update(is_active=data["is_active"])

        return tenant


class SaaSSellerSerializer(serializers.ModelSerializer):
    metrics = serializers.SerializerMethodField()
    invite_link = serializers.SerializerMethodField()
    ref_code = serializers.CharField(source="invite_code", read_only=True)

    class Meta:
        model = SaaSSeller
        fields = (
            "id",
            "full_name",
            "email",
            "phone",
            "ref_code",
            "invite_code",
            "invite_link",
            "is_active",
            "metrics",
            "created_at",
        )

    def get_invite_link(self, obj: SaaSSeller):
        base_url = (getattr(settings, "LAUNCH_SIGNUP_BASE_URL", "") or "").rstrip("/")
        if not base_url:
            base_url = "http://localhost:5173" if settings.DEBUG else "https://launch.goklinik.com"

        parsed = urlparse(base_url)
        host = (parsed.hostname or "").lower()
        is_launch_domain = host in {"launch.goklinik.com", "www.launch.goklinik.com"}

        default_path = "/" if is_launch_domain else "/signup"
        default_ref_param = "r" if is_launch_domain else "ref_code"

        configured_path = (getattr(settings, "LAUNCH_SIGNUP_PATH", "") or "").strip() or default_path
        if not configured_path.startswith("/"):
            configured_path = f"/{configured_path}"

        ref_param = (getattr(settings, "LAUNCH_REF_QUERY_PARAM", "") or "").strip() or default_ref_param

        query = dict(parse_qsl(parsed.query, keep_blank_values=True))
        query[ref_param] = obj.invite_code

        return parsed._replace(
            path=configured_path,
            params="",
            query=urlencode(query),
            fragment="",
        ).geturl()

    def get_metrics(self, obj: SaaSSeller):
        qs = obj.signup_requests.all()
        sent = qs.count()
        accepted = qs.filter(
            status=SaaSClinicSignupRequest.StatusChoices.VERIFIED,
        ).count()
        leads_total = obj.leads.count()
        return {
            "invites_sent": sent,
            "invites_accepted": accepted,
            "signups_completed": accepted,
            "leads_total": leads_total,
        }


class SaaSSellerCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = SaaSSeller
        fields = ("full_name", "email", "phone", "is_active")

    def validate_email(self, value):
        lowered = value.lower()
        qs = SaaSSeller.objects.filter(email__iexact=lowered)
        if self.instance:
            qs = qs.exclude(id=self.instance.id)
        if qs.exists():
            raise serializers.ValidationError("Já existe um vendedor com este e-mail.")
        return lowered


class SaaSSignupRequestCodeSerializer(serializers.Serializer):
    clinic_name = serializers.CharField(max_length=255)
    full_name = serializers.CharField(max_length=255)
    email = serializers.EmailField()
    phone = serializers.CharField(max_length=30, required=False, allow_blank=True)
    tax_number = serializers.CharField(max_length=20, required=False, allow_blank=True)
    password = serializers.CharField(min_length=8, write_only=True)
    plan = serializers.ChoiceField(choices=Tenant.PlanChoices.choices, default=Tenant.PlanChoices.STARTER)
    seller_code = serializers.CharField(max_length=16, required=False, allow_blank=True)
    language = serializers.CharField(max_length=32, required=False, allow_blank=True)

    def validate_email(self, value):
        lowered = value.lower()
        if GoKlinikUser.objects.filter(email__iexact=lowered).exists():
            raise serializers.ValidationError("Já existe um usuário com este e-mail.")
        return lowered

    def validate(self, attrs):
        seller_code = (attrs.get("seller_code") or "").strip().upper()
        attrs["seller"] = None
        if seller_code:
            seller = SaaSSeller.objects.filter(invite_code=seller_code, is_active=True).first()
            if not seller:
                raise serializers.ValidationError({"seller_code": "Código de vendedor inválido."})
            attrs["seller"] = seller
        return attrs

    def create(self, validated_data):
        seller = validated_data.pop("seller", None)
        seller_code = validated_data.pop("seller_code", "")
        if seller_code:
            validated_data.pop("seller_code", None)
        language = normalize_invite_email_language(validated_data.pop("language", None))
        email = validated_data["email"].lower()
        code = get_random_string(6, allowed_chars="0123456789")

        SaaSClinicSignupRequest.objects.filter(
            owner_email__iexact=email,
            flow=SaaSClinicSignupRequest.FlowChoices.SELF_SIGNUP,
            status=SaaSClinicSignupRequest.StatusChoices.PENDING,
        ).update(status=SaaSClinicSignupRequest.StatusChoices.CANCELLED)

        signup_request = SaaSClinicSignupRequest.objects.create(
            flow=SaaSClinicSignupRequest.FlowChoices.SELF_SIGNUP,
            status=SaaSClinicSignupRequest.StatusChoices.PENDING,
            clinic_name=validated_data["clinic_name"].strip(),
            clinic_slug=build_unique_tenant_slug(validated_data["clinic_name"]),
            plan=validated_data["plan"],
            owner_full_name=validated_data["full_name"].strip(),
            owner_email=email,
            owner_phone=(validated_data.get("phone") or "").strip(),
            owner_tax_number=(validated_data.get("tax_number") or "").strip(),
            password_hash=make_password(validated_data["password"]),
            verification_code=code,
            verification_expires_at=timezone.now() + timedelta(minutes=15),
            seller=seller,
        )
        send_signup_code_email(email=email, code=code, language=language)
        return signup_request


class SaaSSignupVerifyCodeSerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(max_length=6)

    def validate(self, attrs):
        email = attrs["email"].lower()
        code = (attrs["code"] or "").strip()
        signup_request = SaaSClinicSignupRequest.objects.filter(
            owner_email__iexact=email,
            flow=SaaSClinicSignupRequest.FlowChoices.SELF_SIGNUP,
            status=SaaSClinicSignupRequest.StatusChoices.PENDING,
        ).order_by("-created_at").first()
        if not signup_request:
            raise serializers.ValidationError({"code": "Código inválido ou expirado."})
        if not signup_request.verification_expires_at or signup_request.verification_expires_at < timezone.now():
            signup_request.status = SaaSClinicSignupRequest.StatusChoices.EXPIRED
            signup_request.save(update_fields=["status", "updated_at"])
            raise serializers.ValidationError({"code": "Código expirado. Solicite um novo código."})
        if signup_request.verification_code != code:
            raise serializers.ValidationError({"code": "Código inválido."})
        if GoKlinikUser.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError({"email": "Este e-mail já possui cadastro."})

        attrs["signup_request"] = signup_request
        return attrs

    def create(self, validated_data):
        signup_request: SaaSClinicSignupRequest = validated_data["signup_request"]
        first_name, last_name = split_full_name(signup_request.owner_full_name)

        with transaction.atomic():
            tenant = Tenant.objects.create(
                name=signup_request.clinic_name,
                slug=build_unique_tenant_slug(signup_request.clinic_name),
                plan=signup_request.plan,
                is_active=True,
            )
            owner = GoKlinikUser.objects.create(
                email=signup_request.owner_email.lower(),
                first_name=first_name,
                last_name=last_name,
                role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
                tenant=tenant,
                cpf=signup_request.owner_tax_number,
                phone=signup_request.owner_phone,
                is_staff=True,
                is_active=True,
            )
            owner.password = signup_request.password_hash
            owner.save(update_fields=["password"])

            signup_request.status = SaaSClinicSignupRequest.StatusChoices.VERIFIED
            signup_request.tenant = tenant
            signup_request.accepted_at = timezone.now()
            signup_request.save(update_fields=["status", "tenant", "accepted_at", "updated_at"])

        return owner


class SaaSInviteAcceptSerializer(serializers.Serializer):
    token = serializers.UUIDField()
    password = serializers.CharField(min_length=8, write_only=True)
    phone = serializers.CharField(max_length=30, required=False, allow_blank=True)
    tax_number = serializers.CharField(max_length=20, required=False, allow_blank=True)

    def validate(self, attrs):
        token = attrs["token"]
        signup_request = SaaSClinicSignupRequest.objects.filter(
            invite_token=token,
            flow=SaaSClinicSignupRequest.FlowChoices.SAAS_INVITE,
            status=SaaSClinicSignupRequest.StatusChoices.PENDING,
        ).first()
        if not signup_request:
            raise serializers.ValidationError({"token": "Convite inválido ou expirado."})
        if signup_request.verification_expires_at and signup_request.verification_expires_at < timezone.now():
            signup_request.status = SaaSClinicSignupRequest.StatusChoices.EXPIRED
            signup_request.save(update_fields=["status", "updated_at"])
            raise serializers.ValidationError({"token": "Convite expirado."})
        if GoKlinikUser.objects.filter(email__iexact=signup_request.owner_email).exists():
            raise serializers.ValidationError({"token": "Este convite já foi utilizado."})
        attrs["signup_request"] = signup_request
        return attrs

    def create(self, validated_data):
        signup_request: SaaSClinicSignupRequest = validated_data["signup_request"]
        password = validated_data["password"]
        phone = (validated_data.get("phone") or "").strip() or signup_request.owner_phone
        tax_number = (validated_data.get("tax_number") or "").strip() or signup_request.owner_tax_number
        first_name, last_name = split_full_name(signup_request.owner_full_name)

        with transaction.atomic():
            tenant = Tenant.objects.create(
                name=signup_request.clinic_name,
                slug=build_unique_tenant_slug(signup_request.clinic_name),
                plan=signup_request.plan,
                is_active=True,
            )
            owner = GoKlinikUser.objects.create_user(
                email=signup_request.owner_email.lower(),
                password=password,
                first_name=first_name,
                last_name=last_name,
                role=GoKlinikUser.RoleChoices.CLINIC_MASTER,
                tenant=tenant,
                cpf=tax_number,
                phone=phone,
                is_staff=True,
                is_active=True,
            )
            signup_request.status = SaaSClinicSignupRequest.StatusChoices.VERIFIED
            signup_request.tenant = tenant
            signup_request.accepted_at = timezone.now()
            signup_request.save(update_fields=["status", "tenant", "accepted_at", "updated_at"])

        return owner
