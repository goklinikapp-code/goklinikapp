from __future__ import annotations

from functools import wraps

from apps.patients.models import Patient

from .models import MedicalRecordAccessLog


def log_record_access(request, patient, action: str):
    ip = request.META.get("REMOTE_ADDR", "")
    user_agent = request.META.get("HTTP_USER_AGENT", "")
    MedicalRecordAccessLog.objects.create(
        patient=patient,
        accessed_by=request.user if request.user.is_authenticated else None,
        action=action,
        ip_address=ip,
        user_agent=user_agent,
    )


def record_medical_access(action: str):
    def decorator(func):
        @wraps(func)
        def wrapper(view, request, *args, **kwargs):
            response = func(view, request, *args, **kwargs)
            patient_id = kwargs.get("patient_id")
            if patient_id and request.user.is_authenticated:
                patient = Patient.objects.filter(id=patient_id).first()
                if patient:
                    log_record_access(request, patient, action)
            return response

        return wrapper

    return decorator
