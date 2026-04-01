from __future__ import annotations

from rest_framework import serializers

from config.media_urls import AbsoluteMediaUrlsSerializerMixin

from .models import (
    MedicalDocument,
    MedicalRecordAccessLog,
    PatientDocument,
    PatientMedication,
    PatientProcedure,
    PatientProcedureImage,
)


class MedicalDocumentSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    uploaded_by = serializers.SerializerMethodField()

    class Meta:
        model = MedicalDocument
        fields = (
            "id",
            "document_type",
            "title",
            "file_url",
            "uploaded_by",
            "is_signed",
            "valid_until",
            "created_at",
        )
        read_only_fields = fields

    def get_uploaded_by(self, obj):
        if not obj.uploaded_by:
            return None
        return obj.uploaded_by.full_name


class MedicalDocumentCreateSerializer(serializers.Serializer):
    document_type = serializers.ChoiceField(choices=MedicalDocument.DocumentTypeChoices.choices)
    title = serializers.CharField(max_length=255)
    file = serializers.FileField(required=False)
    file_url = serializers.URLField(required=False)
    is_signed = serializers.BooleanField(required=False, default=False)
    valid_until = serializers.DateField(required=False, allow_null=True)

    def validate(self, attrs):
        if not attrs.get("file") and not attrs.get("file_url"):
            raise serializers.ValidationError("file or file_url is required.")
        return attrs


class MedicalRecordAccessLogSerializer(serializers.ModelSerializer):
    accessed_by = serializers.SerializerMethodField()

    class Meta:
        model = MedicalRecordAccessLog
        fields = ("id", "accessed_by", "action", "accessed_at", "ip_address")
        read_only_fields = fields

    def get_accessed_by(self, obj):
        if not obj.accessed_by:
            return None
        return {
            "name": obj.accessed_by.full_name,
            "role": obj.accessed_by.role,
        }


class PatientMedicationSerializer(serializers.ModelSerializer):
    class Meta:
        model = PatientMedication
        fields = (
            "id",
            "nome_medicamento",
            "dosagem",
            "frequencia",
            "via_administracao",
            "data_inicio",
            "data_fim",
            "em_uso",
            "possui_alergia",
            "descricao",
            "criado_em",
            "atualizado_em",
        )
        read_only_fields = ("id", "criado_em", "atualizado_em")


class PatientMedicationWriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = PatientMedication
        fields = (
            "nome_medicamento",
            "dosagem",
            "frequencia",
            "via_administracao",
            "data_inicio",
            "data_fim",
            "em_uso",
            "possui_alergia",
            "descricao",
        )

    def validate_nome_medicamento(self, value):
        cleaned = (value or "").strip()
        if len(cleaned) < 2:
            raise serializers.ValidationError("Informe o nome do medicamento.")
        return cleaned

    def validate(self, attrs):
        start_date = attrs.get("data_inicio")
        end_date = attrs.get("data_fim")
        if start_date and end_date and end_date < start_date:
            raise serializers.ValidationError({"data_fim": "A data final deve ser maior ou igual à data inicial."})
        return attrs


class PatientProcedureImageSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    class Meta:
        model = PatientProcedureImage
        fields = ("id", "image_url", "criado_em")
        read_only_fields = fields


class PatientProcedureSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    images = PatientProcedureImageSerializer(many=True, read_only=True)

    class Meta:
        model = PatientProcedure
        fields = (
            "id",
            "nome_procedimento",
            "descricao",
            "data_procedimento",
            "profissional_responsavel",
            "observacoes",
            "images",
            "criado_em",
            "atualizado_em",
        )
        read_only_fields = ("id", "images", "criado_em", "atualizado_em")


class PatientProcedureWriteSerializer(serializers.ModelSerializer):
    images = serializers.ListField(child=serializers.FileField(), required=False, allow_empty=True)
    image_urls = serializers.ListField(
        child=serializers.URLField(),
        required=False,
        allow_empty=True,
    )

    class Meta:
        model = PatientProcedure
        fields = (
            "nome_procedimento",
            "descricao",
            "data_procedimento",
            "profissional_responsavel",
            "observacoes",
            "images",
            "image_urls",
        )

    def validate_nome_procedimento(self, value):
        cleaned = (value or "").strip()
        if len(cleaned) < 2:
            raise serializers.ValidationError("Informe o nome do procedimento.")
        return cleaned


class PatientDocumentSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    uploaded_by = serializers.SerializerMethodField()

    class Meta:
        model = PatientDocument
        fields = (
            "id",
            "titulo",
            "descricao",
            "arquivo_url",
            "tipo_arquivo",
            "uploaded_by",
            "criado_em",
        )
        read_only_fields = fields

    def get_uploaded_by(self, obj):
        if not obj.uploaded_by:
            return None
        return obj.uploaded_by.full_name


class PatientDocumentWriteSerializer(serializers.Serializer):
    titulo = serializers.CharField(max_length=255)
    descricao = serializers.CharField(required=False, allow_blank=True)
    tipo_arquivo = serializers.ChoiceField(
        choices=PatientDocument.TipoArquivoChoices.choices,
        required=False,
    )
    file = serializers.FileField(required=False)
    file_url = serializers.URLField(required=False)

    def validate_titulo(self, value):
        cleaned = (value or "").strip()
        if len(cleaned) < 2:
            raise serializers.ValidationError("Informe o título do documento.")
        return cleaned

    def validate(self, attrs):
        if self.partial and "file" not in attrs and "file_url" not in attrs:
            return attrs
        if not attrs.get("file") and not attrs.get("file_url"):
            raise serializers.ValidationError("file ou file_url é obrigatório.")
        if "tipo_arquivo" not in attrs:
            file = attrs.get("file")
            file_url = (attrs.get("file_url") or "").lower()
            if file and (getattr(file, "content_type", "") or "").startswith("image/"):
                attrs["tipo_arquivo"] = PatientDocument.TipoArquivoChoices.IMAGEM
            elif file_url.endswith((".png", ".jpg", ".jpeg", ".webp")):
                attrs["tipo_arquivo"] = PatientDocument.TipoArquivoChoices.IMAGEM
            else:
                attrs["tipo_arquivo"] = PatientDocument.TipoArquivoChoices.PDF
        return attrs
