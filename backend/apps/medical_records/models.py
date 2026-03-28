from __future__ import annotations

import uuid

from django.db import models


class MedicalDocument(models.Model):
    class DocumentTypeChoices(models.TextChoices):
        CONSENT_FORM = "consent_form", "Consent Form"
        PRESCRIPTION = "prescription", "Prescription"
        EXAM = "exam", "Exam"
        REPORT = "report", "Report"
        OTHER = "other", "Other"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="medical_documents",
    )
    tenant = models.ForeignKey("tenants.Tenant", on_delete=models.CASCADE, related_name="medical_documents")
    document_type = models.CharField(max_length=20, choices=DocumentTypeChoices.choices)
    title = models.CharField(max_length=255)
    file_url = models.URLField()
    uploaded_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="uploaded_medical_documents",
    )
    is_signed = models.BooleanField(default=False)
    valid_until = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "medical_documents"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.patient.full_name} - {self.title}"


class MedicalRecordAccessLog(models.Model):
    class ActionChoices(models.TextChoices):
        VIEW = "view", "View"
        EDIT = "edit", "Edit"
        PRINT = "print", "Print"
        DOWNLOAD = "download", "Download"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="medical_record_access_logs",
    )
    accessed_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="medical_access_logs",
    )
    action = models.CharField(max_length=20, choices=ActionChoices.choices)
    ip_address = models.CharField(max_length=64, blank=True)
    user_agent = models.TextField(blank=True)
    accessed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "medical_record_access_logs"
        ordering = ["-accessed_at"]

    def __str__(self):
        return f"{self.patient.full_name} - {self.action}"


class PatientMedication(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="patient_medications",
    )
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="patient_medications",
    )
    nome_medicamento = models.CharField(max_length=255)
    dosagem = models.CharField(max_length=120, blank=True)
    frequencia = models.CharField(max_length=120, blank=True)
    via_administracao = models.CharField(max_length=120, blank=True)
    data_inicio = models.DateField()
    data_fim = models.DateField(null=True, blank=True)
    em_uso = models.BooleanField(default=True)
    possui_alergia = models.BooleanField(default=False)
    descricao = models.TextField(blank=True)
    criado_em = models.DateTimeField(auto_now_add=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "patient_medications"
        ordering = ["-em_uso", "-data_inicio", "-criado_em"]
        indexes = [
            models.Index(fields=["patient", "em_uso"]),
            models.Index(fields=["tenant", "criado_em"]),
        ]

    def __str__(self):
        return f"{self.patient.full_name} - {self.nome_medicamento}"


class PatientProcedure(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="patient_procedures",
    )
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="patient_procedures",
    )
    nome_procedimento = models.CharField(max_length=255)
    descricao = models.TextField(blank=True)
    data_procedimento = models.DateField()
    profissional_responsavel = models.CharField(max_length=255, blank=True)
    observacoes = models.TextField(blank=True)
    criado_em = models.DateTimeField(auto_now_add=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "patient_procedures"
        ordering = ["-data_procedimento", "-criado_em"]
        indexes = [
            models.Index(fields=["patient", "data_procedimento"]),
            models.Index(fields=["tenant", "criado_em"]),
        ]

    def __str__(self):
        return f"{self.patient.full_name} - {self.nome_procedimento}"


class PatientProcedureImage(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    procedure = models.ForeignKey(
        "medical_records.PatientProcedure",
        on_delete=models.CASCADE,
        related_name="images",
    )
    image_url = models.URLField()
    criado_em = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "patient_procedure_images"
        ordering = ["criado_em"]

    def __str__(self):
        return f"{self.procedure_id} - image"


class PatientDocument(models.Model):
    class TipoArquivoChoices(models.TextChoices):
        PDF = "pdf", "PDF"
        IMAGEM = "imagem", "Imagem"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        "patients.Patient",
        on_delete=models.CASCADE,
        related_name="patient_documents",
    )
    tenant = models.ForeignKey(
        "tenants.Tenant",
        on_delete=models.CASCADE,
        related_name="patient_documents",
    )
    titulo = models.CharField(max_length=255)
    descricao = models.TextField(blank=True)
    arquivo_url = models.URLField()
    tipo_arquivo = models.CharField(
        max_length=20,
        choices=TipoArquivoChoices.choices,
        default=TipoArquivoChoices.PDF,
    )
    criado_em = models.DateTimeField(auto_now_add=True)
    uploaded_by = models.ForeignKey(
        "users.GoKlinikUser",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="uploaded_patient_documents",
    )

    class Meta:
        db_table = "patient_documents"
        ordering = ["-criado_em"]
        indexes = [
            models.Index(fields=["patient", "criado_em"]),
            models.Index(fields=["tenant", "criado_em"]),
        ]

    def __str__(self):
        return f"{self.patient.full_name} - {self.titulo}"
