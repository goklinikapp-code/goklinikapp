import uuid
from urllib.parse import parse_qs, urlparse

from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils.crypto import get_random_string

SELLER_CODE_ALLOWED_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


class GoKlinikUserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, email, password, **extra_fields):
        if not email:
            raise ValueError("The given email must be set")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("role", GoKlinikUser.RoleChoices.SUPER_ADMIN)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        return self._create_user(email, password, **extra_fields)


class GoKlinikUser(AbstractUser):
    class RoleChoices(models.TextChoices):
        SUPER_ADMIN = "super_admin", "Super Admin"
        CLINIC_MASTER = "clinic_master", "Clinic Master"
        SURGEON = "surgeon", "Surgeon"
        SECRETARY = "secretary", "Secretary"
        NURSE = "nurse", "Nurse"
        PATIENT = "patient", "Patient"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    username = None
    email = models.EmailField(unique=True)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        related_name="users",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    role = models.CharField(
        max_length=20,
        choices=RoleChoices.choices,
        default=RoleChoices.PATIENT,
    )
    phone = models.CharField(max_length=30, blank=True)
    cpf = models.CharField(max_length=14, blank=True)
    referral_code = models.CharField(max_length=20, unique=True, blank=True, null=True)
    referred_by = models.ForeignKey(
        "self",
        related_name="referred_patients",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    date_of_birth = models.DateField(null=True, blank=True)
    avatar_url = models.URLField(blank=True)
    bio = models.TextField(blank=True)
    crm_number = models.CharField(max_length=60, blank=True)
    years_experience = models.PositiveIntegerField(null=True, blank=True)
    is_visible_in_app = models.BooleanField(default=True)
    access_permissions = models.JSONField(default=list, blank=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    objects = GoKlinikUserManager()

    class Meta:
        db_table = "users"
        indexes = [
            models.Index(fields=["tenant", "role"]),
            models.Index(fields=["email"]),
        ]

    def __str__(self) -> str:
        return self.email

    @property
    def full_name(self) -> str:
        joined = f"{self.first_name} {self.last_name}".strip()
        return joined or self.email


class UploadedImageAsset(models.Model):
    class TargetChoices(models.TextChoices):
        PATIENT = "patient", "Patient"
        CLINIC = "clinic", "Clinic"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        "tenants.Tenant",
        related_name="uploaded_image_assets",
        on_delete=models.CASCADE,
    )
    patient = models.ForeignKey(
        "patients.Patient",
        related_name="uploaded_image_assets",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
    )
    target = models.CharField(
        max_length=20,
        choices=TargetChoices.choices,
    )
    image_url = models.URLField(max_length=2048)
    storage_path = models.CharField(max_length=512)
    uploaded_by = models.ForeignKey(
        "users.GoKlinikUser",
        related_name="assets_uploaded",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "uploaded_image_assets"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["tenant", "target"]),
            models.Index(fields=["patient"]),
            models.Index(fields=["created_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.target}:{self.image_url}"


class SaaSSeller(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    full_name = models.CharField(max_length=255)
    email = models.EmailField(unique=True)
    phone = models.CharField(max_length=30, blank=True)
    invite_code = models.CharField(max_length=16, unique=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "saas_sellers"
        ordering = ["full_name"]
        indexes = [
            models.Index(fields=["email"]),
            models.Index(fields=["invite_code"]),
            models.Index(fields=["is_active"]),
        ]

    def __str__(self) -> str:
        return self.full_name

    @staticmethod
    def _generate_invite_code() -> str:
        while True:
            code = get_random_string(10, allowed_chars=SELLER_CODE_ALLOWED_CHARS)
            if not SaaSSeller.objects.filter(invite_code=code).exists():
                return code

    def save(self, *args, **kwargs):
        if not self.invite_code:
            self.invite_code = self._generate_invite_code()
        self.email = (self.email or "").lower()
        super().save(*args, **kwargs)


class SaaSClinicSignupRequest(models.Model):
    class FlowChoices(models.TextChoices):
        SELF_SIGNUP = "self_signup", "Self signup"
        SAAS_INVITE = "saas_invite", "SaaS invite"

    class StatusChoices(models.TextChoices):
        PENDING = "pending", "Pending"
        VERIFIED = "verified", "Verified"
        EXPIRED = "expired", "Expired"
        CANCELLED = "cancelled", "Cancelled"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    flow = models.CharField(
        max_length=24,
        choices=FlowChoices.choices,
        default=FlowChoices.SELF_SIGNUP,
    )
    status = models.CharField(
        max_length=16,
        choices=StatusChoices.choices,
        default=StatusChoices.PENDING,
    )
    clinic_name = models.CharField(max_length=255)
    clinic_slug = models.SlugField(max_length=80, blank=True)
    plan = models.CharField(max_length=20, default="starter")
    owner_full_name = models.CharField(max_length=255)
    owner_email = models.EmailField()
    owner_phone = models.CharField(max_length=30, blank=True)
    owner_tax_number = models.CharField(max_length=20, blank=True)
    password_hash = models.CharField(max_length=255, blank=True)
    verification_code = models.CharField(max_length=6, blank=True)
    verification_expires_at = models.DateTimeField(null=True, blank=True)
    invite_token = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    seller = models.ForeignKey(
        "users.SaaSSeller",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="signup_requests",
    )
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="signup_requests",
    )
    created_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_signup_requests",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    accepted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "saas_clinic_signup_requests"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["owner_email", "status"]),
            models.Index(fields=["flow", "status"]),
            models.Index(fields=["created_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.owner_email} ({self.flow})"


class SaaSAISettings(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    provider = models.CharField(max_length=30, default="grok")
    model_name = models.CharField(max_length=80, default="grok-4-1-fast")
    endpoint_url = models.URLField(default="https://api.x.ai/v1/chat/completions")
    api_key = models.CharField(max_length=255, blank=True)
    temperature = models.DecimalField(max_digits=4, decimal_places=2, default=0)
    max_tokens = models.PositiveIntegerField(default=600)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "saas_ai_settings"
        ordering = ["-updated_at"]

    def __str__(self) -> str:
        return f"{self.provider}:{self.model_name}"

    @property
    def api_key_masked(self) -> str:
        value = (self.api_key or "").strip()
        if not value:
            return ""
        if len(value) <= 8:
            return "•" * len(value)
        return f"{value[:4]}{'•' * (len(value) - 8)}{value[-4:]}"


def get_saas_ai_settings() -> SaaSAISettings:
    settings = SaaSAISettings.objects.order_by("-updated_at").first()
    if settings:
        return settings
    return SaaSAISettings.objects.create()


def extract_youtube_video_id(raw_url: str) -> str:
    if not raw_url:
        return ""

    parsed = urlparse(raw_url.strip())
    host = (parsed.netloc or "").lower()
    path = (parsed.path or "").strip("/")

    if host.endswith("youtu.be"):
        return path.split("/")[0] if path else ""

    if "youtube.com" in host:
        if path == "watch":
            return (parse_qs(parsed.query).get("v") or [""])[0]
        if path.startswith("embed/"):
            return path.split("/", 1)[1].split("/")[0]
        if path.startswith("shorts/"):
            return path.split("/", 1)[1].split("/")[0]

    return ""


class TutorialVideo(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    youtube_url = models.URLField()
    youtube_video_id = models.CharField(max_length=32, blank=True)
    thumbnail_url = models.URLField(blank=True)
    duration_minutes = models.PositiveIntegerField(null=True, blank=True)
    order_index = models.PositiveIntegerField(default=1)
    is_published = models.BooleanField(default=True)
    created_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_tutorial_videos",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "tutorial_videos"
        ordering = ["order_index", "created_at"]
        indexes = [
            models.Index(fields=["is_published"]),
            models.Index(fields=["order_index"]),
            models.Index(fields=["created_at"]),
        ]

    def __str__(self) -> str:
        return self.title

    @property
    def embed_url(self) -> str:
        if not self.youtube_video_id:
            return ""
        return f"https://www.youtube.com/embed/{self.youtube_video_id}"

    def save(self, *args, **kwargs):
        self.youtube_video_id = extract_youtube_video_id(self.youtube_url)
        if self.youtube_video_id and not (self.thumbnail_url or "").strip():
            self.thumbnail_url = f"https://img.youtube.com/vi/{self.youtube_video_id}/hqdefault.jpg"
        super().save(*args, **kwargs)


class TutorialProgress(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.CASCADE,
        related_name="tutorial_progress",
    )
    video = models.ForeignKey(
        "users.TutorialVideo",
        on_delete=models.CASCADE,
        related_name="progress_entries",
    )
    completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "tutorial_progress"
        unique_together = ("user", "video")
        indexes = [
            models.Index(fields=["user", "completed"]),
            models.Index(fields=["updated_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.user_id}:{self.video_id}:{self.completed}"
