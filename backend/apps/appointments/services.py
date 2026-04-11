from __future__ import annotations

from datetime import datetime, time, timedelta

from django.utils import timezone

from .models import Appointment, BlockedPeriod, ProfessionalAvailability


class AppointmentService:
    SLOT_DURATION_MINUTES = 30

    _BLOCKING_STATUSES = (
        Appointment.StatusChoices.PENDING,
        Appointment.StatusChoices.CONFIRMED,
        Appointment.StatusChoices.IN_PROGRESS,
    )

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
            status__in=AppointmentService._BLOCKING_STATUSES,
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
        _ = specialty_id

        weekday = date.weekday()
        availabilities = ProfessionalAvailability.objects.filter(
            professional_id=professional_id,
            day_of_week=weekday,
            is_active=True,
        ).order_by("start_time")

        if not availabilities.exists():
            return []

        appointments = Appointment.objects.filter(
            professional_id=professional_id,
            appointment_date=date,
            status__in=AppointmentService._BLOCKING_STATUSES,
        )
        if exclude_appointment_id:
            appointments = appointments.exclude(id=exclude_appointment_id)

        blocked_periods = BlockedPeriod.objects.filter(
            professional_id=professional_id,
            start_datetime__date__lte=date,
            end_datetime__date__gte=date,
        ).order_by("start_datetime")

        tz = timezone.get_current_timezone()
        day_start = timezone.make_aware(datetime.combine(date, time(0, 0)), tz)
        day_end = day_start + timedelta(days=1)

        blocked_ranges: list[tuple[datetime, datetime]] = []
        for block in blocked_periods:
            start_datetime = block.start_datetime
            end_datetime = block.end_datetime
            if timezone.is_naive(start_datetime):
                start_datetime = timezone.make_aware(start_datetime, tz)
            if timezone.is_naive(end_datetime):
                end_datetime = timezone.make_aware(end_datetime, tz)

            if start_datetime <= day_start and end_datetime >= day_end:
                return []

            blocked_ranges.append((start_datetime, end_datetime))

        appointment_ranges: list[tuple[datetime, datetime]] = []
        for app in appointments:
            app_start = timezone.make_aware(
                datetime.combine(app.appointment_date, app.appointment_time),
                tz,
            )
            app_end = app_start + timedelta(minutes=app.duration_minutes or 60)
            appointment_ranges.append((app_start, app_end))

        now = timezone.localtime()
        available: list[str] = []

        for availability in availabilities:
            start_dt = timezone.make_aware(
                datetime.combine(date, availability.start_time),
                tz,
            )
            end_dt = timezone.make_aware(
                datetime.combine(date, availability.end_time),
                tz,
            )

            current = start_dt
            while current + timedelta(minutes=AppointmentService.SLOT_DURATION_MINUTES) <= end_dt:
                slot_end = current + timedelta(minutes=AppointmentService.SLOT_DURATION_MINUTES)

                if current <= now:
                    current += timedelta(minutes=AppointmentService.SLOT_DURATION_MINUTES)
                    continue

                overlaps_appointment = any(
                    current < app_end and slot_end > app_start
                    for app_start, app_end in appointment_ranges
                )
                if overlaps_appointment:
                    current += timedelta(minutes=AppointmentService.SLOT_DURATION_MINUTES)
                    continue

                overlaps_block = any(
                    current < block_end and slot_end > block_start
                    for block_start, block_end in blocked_ranges
                )
                if not overlaps_block:
                    available.append(current.strftime("%H:%M"))

                current += timedelta(minutes=AppointmentService.SLOT_DURATION_MINUTES)

        return available
