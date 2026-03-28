import uuid

from django.core.validators import RegexValidator
from django.db import models

hex_color_validator = RegexValidator(
    regex=r"^#(?:[0-9a-fA-F]{3}){1,2}$",
    message="Color must be a valid hex value like #0D5C73.",
)

DEFAULT_AI_ASSISTANT_PROMPT = (
    "Você é a assistente virtual da clínica. "
    "Atenda com empatia, objetividade e linguagem simples. "
    "Responda somente com base no contexto do próprio paciente autenticado. "
    "Nunca revele, invente ou inferira dados de outros pacientes. "
    "Se faltar informação clínica, oriente o paciente a falar com a equipe médica."
)


class Tenant(models.Model):
    class PlanChoices(models.TextChoices):
        STARTER = "starter", "Starter"
        PROFESSIONAL = "professional", "Professional"
        ENTERPRISE = "enterprise", "Enterprise"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    slug = models.SlugField(max_length=80, unique=True)
    plan = models.CharField(
        max_length=20,
        choices=PlanChoices.choices,
        default=PlanChoices.STARTER,
    )
    primary_color = models.CharField(
        max_length=7,
        default="#0D5C73",
        validators=[hex_color_validator],
    )
    secondary_color = models.CharField(
        max_length=7,
        default="#4A7C59",
        validators=[hex_color_validator],
    )
    accent_color = models.CharField(
        max_length=7,
        default="#C8992E",
        validators=[hex_color_validator],
    )
    logo_url = models.URLField(blank=True, null=True)
    favicon_url = models.URLField(blank=True, null=True)
    clinic_addresses = models.JSONField(default=list, blank=True)
    ai_assistant_prompt = models.TextField(default=DEFAULT_AI_ASSISTANT_PROMPT, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "tenants"
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name

    def get_branding(self) -> dict:
        return {
            "name": self.name,
            "slug": self.slug,
            "primary_color": self.primary_color,
            "secondary_color": self.secondary_color,
            "accent_color": self.accent_color,
            "logo_url": self.logo_url,
            "favicon_url": self.favicon_url,
            "clinic_addresses": self.clinic_addresses or [],
            "ai_assistant_prompt": self.ai_assistant_prompt,
        }


class TenantSpecialty(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.ForeignKey(
        Tenant,
        on_delete=models.CASCADE,
        related_name="specialties",
    )
    specialty_name = models.CharField(max_length=120)
    description = models.TextField(blank=True, default="")
    specialty_icon = models.CharField(max_length=120, blank=True)
    default_duration_minutes = models.PositiveIntegerField(default=60)
    is_active = models.BooleanField(default=True)
    display_order = models.PositiveIntegerField(default=0)

    class Meta:
        db_table = "tenant_specialties"
        ordering = ["display_order", "specialty_name"]
        unique_together = ("tenant", "specialty_name")

    def __str__(self) -> str:
        return f"{self.tenant.slug} - {self.specialty_name}"
