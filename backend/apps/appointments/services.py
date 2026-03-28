from __future__ import annotations

from datetime import datetime, time, timedelta

from django.utils import timezone

from .models import Appointment, BlockedPeriod, ProfessionalAvailability


class AppointmentService:
    _DEFAULT_AVAILABILITY_WINDOWS = {
        0: [(time(9, 0), time(18, 0))],  # Monday
        1: [(time(9, 0), time(18, 0))],  # Tuesday
        2: [(time(9, 0), time(18, 0))],  # Wednesday
        3: [(time(9, 0), time(18, 0))],  # Thursday
        4: [(time(9, 0), time(18, 0))],  # Friday
    }

    @staticmethod
    def get_conflicting_appointment(
        *,
        professional_id,
        appointment_date,
        appointment_time,
        duration_minutes,
        exclude_appointment_id=None,
    ) -> Appointment | None:
        start_dt = datetime.combine(appointment_date, appointment_time)
        end_dt = start_dt + timedelta(minutes=duration_minutes or 60)

        queryset = Appointment.objects.filter(
            professional_id=professional_id,
            appointment_date=appointment_date,
        ).exclude(
            status=Appointment.StatusChoices.CANCELLED,
        )
        if exclude_appointment_id:
            queryset = queryset.exclude(id=exclude_appointment_id)

        for existing in queryset:
            existing_start = datetime.combine(
                existing.appointment_date,
                existing.appointment_time,
            )
            existing_end = existing_start + timedelta(minutes=existing.duration_minutes or 60)
            if start_dt < existing_end and end_dt > existing_start:
                return existing

        return None

    @staticmethod
    def get_available_slots(
        professional_id, date, specialty_id=None, exclude_appointment_id=None
    ) -> list[str]:
        from apps.tenants.models import TenantSpecialty

        slot_duration = 60
        if specialty_id:
            specialty = TenantSpecialty.objects.filter(id=specialty_id).first()
            if specialty is not None:
                slot_duration = getattr(specialty, "default_duration_minutes", 60) or 60

        weekday = date.weekday()
        has_custom_availability = ProfessionalAvailability.objects.filter(
            professional_id=professional_id,
            is_active=True,
        ).exists()

        availabilities = ProfessionalAvailability.objects.filter(
            professional_id=professional_id,
            day_of_week=weekday,
            is_active=True,
        ).order_by("start_time")

        availability_windows = [
            (availability.start_time, availability.end_time)
            for availability in availabilities
        ]
        if not has_custom_availability:
            availability_windows = AppointmentService._DEFAULT_AVAILABILITY_WINDOWS.get(
                weekday, []
            )

        appointments = Appointment.objects.filter(
            professional_id=professional_id,
            appointment_date=date,
        ).exclude(status=Appointment.StatusChoices.CANCELLED)
        if exclude_appointment_id:
            appointments = appointments.exclude(id=exclude_appointment_id)

        blocked_periods = BlockedPeriod.objects.filter(
            professional_id=professional_id,
            start_datetime__date__lte=date,
            end_datetime__date__gte=date,
        )

        now = timezone.localtime()
        available: list[str] = []

        for start_time, end_time in availability_windows:
            start_dt = timezone.make_aware(
                datetime.combine(date, start_time),
                timezone.get_current_timezone(),
            )
            end_dt = timezone.make_aware(
                datetime.combine(date, end_time),
                timezone.get_current_timezone(),
            )

            current = start_dt
            while current + timedelta(minutes=slot_duration) <= end_dt:
                slot_end = current + timedelta(minutes=slot_duration)

                if current <= now:
                    current += timedelta(minutes=slot_duration)
                    continue

                overlaps_appointment = False
                for app in appointments:
                    app_start = timezone.make_aware(
                        datetime.combine(app.appointment_date, app.appointment_time),
                        timezone.get_current_timezone(),
                    )
                    app_end = app_start + timedelta(minutes=app.duration_minutes)
                    if current < app_end and slot_end > app_start:
                        overlaps_appointment = True
                        break

                if overlaps_appointment:
                    current += timedelta(minutes=slot_duration)
                    continue

                overlaps_block = False
                for block in blocked_periods:
                    if current < block.end_datetime and slot_end > block.start_datetime:
                        overlaps_block = True
                        break

                if not overlaps_block:
                    available.append(current.strftime("%H:%M"))

                current += timedelta(minutes=slot_duration)

        return available
