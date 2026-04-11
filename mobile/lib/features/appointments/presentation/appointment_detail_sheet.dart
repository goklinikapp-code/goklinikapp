import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../domain/appointment_models.dart';

class AppointmentDetailSheet extends StatefulWidget {
  const AppointmentDetailSheet({
    super.key,
    required this.appointment,
    required this.language,
    required this.t,
    required this.onConfirmPresence,
  });

  final AppointmentItem appointment;
  final String language;
  final String Function(String key) t;
  final Future<void> Function() onConfirmPresence;

  @override
  State<AppointmentDetailSheet> createState() => _AppointmentDetailSheetState();
}

class _AppointmentDetailSheetState extends State<AppointmentDetailSheet> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final localeTag = localeFromLanguage(widget.language);
    final statusStyle = _statusStyle(widget.appointment.status);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _typeIcon(widget.appointment.type),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _appointmentTypeLabel(widget.appointment.type),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GKCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GKAvatar(
                            name: widget.appointment.professionalName.isEmpty
                                ? widget.t('clinic_team')
                                : widget.appointment.professionalName,
                            imageUrl:
                                widget.appointment.professionalAvatarUrl.isEmpty
                                    ? null
                                    : widget.appointment.professionalAvatarUrl,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.appointment.professionalName.isEmpty
                                  ? widget.t('clinic_team')
                                  : widget.appointment.professionalName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.event_outlined,
                        label: 'Data',
                        value:
                            _formatLongDate(widget.appointment.date, localeTag),
                      ),
                      _InfoRow(
                        icon: Icons.schedule,
                        label: 'Horário',
                        value: _formatAppointmentTime(widget.appointment.time),
                      ),
                      _InfoRow(
                        icon: Icons.flag_outlined,
                        label: 'Status',
                        valueWidget: GKBadge(
                          label: _appointmentStatusLabel(
                              widget.appointment.status),
                          background: statusStyle.background,
                          foreground: statusStyle.foreground,
                        ),
                      ),
                      if (widget.appointment.clinicLocation.trim().isNotEmpty)
                        _InfoRow(
                          icon: Icons.place_outlined,
                          label: 'Endereço / sala',
                          value: widget.appointment.clinicLocation.trim(),
                        ),
                      if ((widget.appointment.durationMinutes ?? 0) > 0)
                        _InfoRow(
                          icon: Icons.timer_outlined,
                          label: 'Duração',
                          value: '${widget.appointment.durationMinutes} min',
                        ),
                    ],
                  ),
                ),
                if (widget.appointment.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GKCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informações importantes',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.appointment.notes.trim(),
                          style: const TextStyle(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (widget.appointment.status == 'pending')
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _handleConfirmPresence,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _submitting ? 'Confirmando...' : 'Confirmar presença',
                      ),
                    ),
                  )
                else if (widget.appointment.status == 'confirmed')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF166534),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Você confirmou sua presença.',
                            style: TextStyle(
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfirmPresence() async {
    setState(() => _submitting = true);
    try {
      await widget.onConfirmPresence();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _extractApiError(
              error,
              fallback: 'Não foi possível confirmar sua presença.',
            ),
          ),
        ),
      );
      setState(() => _submitting = false);
    }
  }

  IconData _typeIcon(String type) {
    switch (type.trim().toLowerCase()) {
      case 'surgery':
        return Icons.medical_services_outlined;
      case 'return':
        return Icons.reply_outlined;
      case 'post_op_7d':
      case 'post_op_30d':
      case 'post_op_90d':
        return Icons.assignment_turned_in_outlined;
      default:
        return Icons.event_note_outlined;
    }
  }

  String _appointmentTypeLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'first_visit':
        return widget.t('appointments_type_first_visit');
      case 'return':
        return widget.t('appointments_type_return');
      case 'surgery':
        return widget.t('appointments_type_surgery');
      case 'post_op_7d':
        return widget.t('appointments_type_post_op_7d');
      case 'post_op_30d':
        return widget.t('appointments_type_post_op_30d');
      case 'post_op_90d':
        return widget.t('appointments_type_post_op_90d');
      default:
        return widget.t('appointments_type_unknown');
    }
  }

  String _appointmentStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return widget.t('appointments_status_pending');
      case 'confirmed':
        return widget.t('appointments_status_confirmed');
      case 'in_progress':
        return widget.t('appointments_status_in_progress');
      case 'completed':
        return widget.t('appointments_status_completed');
      case 'cancelled':
        return widget.t('appointments_status_cancelled');
      case 'rescheduled':
        return widget.t('appointments_status_rescheduled');
      default:
        return status;
    }
  }

  _StatusStyle _statusStyle(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return const _StatusStyle(
          background: Color(0xFFE2E8F0),
          foreground: Color(0xFF334155),
        );
      case 'confirmed':
        return const _StatusStyle(
          background: Color(0xFFDBEAFE),
          foreground: Color(0xFF1D4ED8),
        );
      case 'in_progress':
        return const _StatusStyle(
          background: Color(0xFFFEF3C7),
          foreground: Color(0xFF92400E),
        );
      case 'completed':
        return const _StatusStyle(
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case 'cancelled':
        return const _StatusStyle(
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        );
      case 'rescheduled':
        return const _StatusStyle(
          background: Color(0xFFEDE9FE),
          foreground: Color(0xFF6D28D9),
        );
      default:
        return const _StatusStyle(
          background: Color(0xFFE2E8F0),
          foreground: Color(0xFF334155),
        );
    }
  }

  String _formatLongDate(DateTime date, String localeTag) {
    final raw =
        DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", localeTag).format(date);
    if (raw.isEmpty) return raw;
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  String _formatAppointmentTime(String rawTime) {
    final normalized = rawTime.trim();
    if (normalized.length >= 5) {
      return normalized.substring(0, 5);
    }
    return normalized;
  }

  String _extractApiError(Object error, {required String fallback}) {
    if (error is DioException) {
      final payload = error.response?.data;
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }

        final values = payload.values.toList(growable: false);
        if (values.isNotEmpty) {
          final first = values.first;
          if (first is List && first.isNotEmpty) {
            return first.first.toString();
          }
          if (first is String && first.trim().isNotEmpty) {
            return first.trim();
          }
        }
      }
    }
    return fallback;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    if ((value == null || value!.trim().isEmpty) && valueWidget == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (valueWidget != null)
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: valueWidget!,
              ),
            )
          else
            Expanded(
              child: Text(
                value!.trim(),
                style: const TextStyle(height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
