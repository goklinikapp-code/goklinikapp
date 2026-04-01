from __future__ import annotations

from rest_framework import serializers

from config.media_urls import AbsoluteMediaUrlsSerializerMixin

from .models import PreOperatory, PreOperatoryFile


class PreOperatoryFileSerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    class Meta:
        model = PreOperatoryFile
        fields = ("id", "file_url", "type", "created_at")
        read_only_fields = fields


class PreOperatorySerializer(AbsoluteMediaUrlsSerializerMixin, serializers.ModelSerializer):
    files = PreOperatoryFileSerializer(many=True, read_only=True)
    photos = serializers.SerializerMethodField()
    documents = serializers.SerializerMethodField()

    class Meta:
        model = PreOperatory
        fields = (
            "id",
            "patient",
            "tenant",
            "allergies",
            "medications",
            "previous_surgeries",
            "diseases",
            "smoking",
            "alcohol",
            "height",
            "weight",
            "status",
            "files",
            "photos",
            "documents",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "id",
            "patient",
            "tenant",
            "status",
            "files",
            "photos",
            "documents",
            "created_at",
            "updated_at",
        )

    def get_photos(self, obj: PreOperatory):
        rows = obj.files.filter(type=PreOperatoryFile.FileTypeChoices.PHOTO)
        return PreOperatoryFileSerializer(
            rows,
            many=True,
            context=self.context,
        ).data

    def get_documents(self, obj: PreOperatory):
        rows = obj.files.filter(type=PreOperatoryFile.FileTypeChoices.DOCUMENT)
        return PreOperatoryFileSerializer(
            rows,
            many=True,
            context=self.context,
        ).data


class PreOperatoryWriteSerializer(serializers.ModelSerializer):
    photos = serializers.ListField(
        child=serializers.FileField(),
        required=False,
        allow_empty=True,
    )
    documents = serializers.ListField(
        child=serializers.FileField(),
        required=False,
        allow_empty=True,
    )

    class Meta:
        model = PreOperatory
        fields = (
            "allergies",
            "medications",
            "previous_surgeries",
            "diseases",
            "smoking",
            "alcohol",
            "height",
            "weight",
            "photos",
            "documents",
        )

    def validate_allergies(self, value: str) -> str:
        return (value or "").strip()

    def validate_medications(self, value: str) -> str:
        return (value or "").strip()

    def validate_previous_surgeries(self, value: str) -> str:
        return (value or "").strip()

    def validate_diseases(self, value: str) -> str:
        return (value or "").strip()

