from django.contrib import admin

from .models import (
    MedicalDocument,
    MedicalRecordAccessLog,
    PatientDocument,
    PatientMedication,
    PatientProcedure,
    PatientProcedureImage,
)


@admin.register(MedicalDocument)
class MedicalDocumentAdmin(admin.ModelAdmin):
    list_display = ("patient", "document_type", "title", "is_signed", "created_at")
    list_filter = ("document_type", "is_signed", "tenant")


@admin.register(MedicalRecordAccessLog)
class MedicalRecordAccessLogAdmin(admin.ModelAdmin):
    list_display = ("patient", "accessed_by", "action", "ip_address", "accessed_at")
    list_filter = ("action",)


@admin.register(PatientMedication)
class PatientMedicationAdmin(admin.ModelAdmin):
    list_display = ("patient", "nome_medicamento", "em_uso", "possui_alergia", "data_inicio", "data_fim")
    list_filter = ("em_uso", "possui_alergia", "data_inicio")
    search_fields = ("patient__first_name", "patient__last_name", "nome_medicamento")


class PatientProcedureImageInline(admin.TabularInline):
    model = PatientProcedureImage
    extra = 0


@admin.register(PatientProcedure)
class PatientProcedureAdmin(admin.ModelAdmin):
    list_display = ("patient", "nome_procedimento", "data_procedimento", "profissional_responsavel", "criado_em")
    list_filter = ("data_procedimento",)
    search_fields = ("patient__first_name", "patient__last_name", "nome_procedimento", "profissional_responsavel")
    inlines = [PatientProcedureImageInline]


@admin.register(PatientDocument)
class PatientDocumentAdmin(admin.ModelAdmin):
    list_display = ("patient", "titulo", "tipo_arquivo", "uploaded_by", "criado_em")
    list_filter = ("tipo_arquivo", "criado_em")
    search_fields = ("patient__first_name", "patient__last_name", "titulo")
