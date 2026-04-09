import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../../../core/widgets/notification_bell_action.dart';
import '../domain/appointment_models.dart';
import 'appointments_controller.dart';

enum AppointmentStatusFilterChip {
  all,
  pending,
  confirmed,
  inProgress,
  completed,
  cancelled,
  rescheduled,
}

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  bool _calendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  AppointmentStatusFilterChip _statusFilter = AppointmentStatusFilterChip.all;

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);
    final appointmentsState = ref.watch(appointmentsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('appointments_nav_title')),
        actions: [
          const NotificationBellAction(),
          IconButton(
            onPressed: () => setState(() => _calendarView = !_calendarView),
            icon: Icon(_calendarView ? Icons.view_list : Icons.calendar_month),
            tooltip: _calendarView
                ? t('appointments_mode_list')
                : t('appointments_mode_calendar'),
          ),
          IconButton(
            onPressed: () => context.push('/schedule/availability'),
            icon: const Icon(Icons.event_available_outlined),
            tooltip: t('doctor_availability_title'),
          ),
          IconButton(
            onPressed: () =>
                ref.read(appointmentsControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: appointmentsState.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 7,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => const GKLoadingShimmer(height: 88),
        ),
        error: (error, _) => Center(
            child: Text('${t('appointments_load_error_prefix')}: $error')),
        data: (appointments) {
          final filteredAppointments = appointments
              .where((item) => _matchesStatusFilter(item, _statusFilter))
              .toList();

          return Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _chip(t('appointments_filter_all'),
                        AppointmentStatusFilterChip.all),
                    _chip(t('appointments_status_pending'),
                        AppointmentStatusFilterChip.pending),
                    _chip(
                      t('appointments_status_confirmed'),
                      AppointmentStatusFilterChip.confirmed,
                    ),
                    _chip(
                      t('appointments_status_in_progress'),
                      AppointmentStatusFilterChip.inProgress,
                    ),
                    _chip(
                      t('appointments_status_completed'),
                      AppointmentStatusFilterChip.completed,
                    ),
                    _chip(
                      t('appointments_status_cancelled'),
                      AppointmentStatusFilterChip.cancelled,
                    ),
                    _chip(
                      t('appointments_status_rescheduled'),
                      AppointmentStatusFilterChip.rescheduled,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _calendarView
                    ? _calendarMode(filteredAppointments, language, t)
                    : _listMode(filteredAppointments, t),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _listMode(
    List<AppointmentItem> appointments,
    String Function(String key) t,
  ) {
    if (appointments.isEmpty) {
      return Center(child: Text(t('appointments_empty_filtered')));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final item = appointments[index];
        return _appointmentCard(item, t);
      },
    );
  }

  Widget _calendarMode(
    List<AppointmentItem> appointments,
    String language,
    String Function(String key) t,
  ) {
    final events = <DateTime, List<AppointmentItem>>{};
    for (final appointment in appointments) {
      final day = DateTime(
        appointment.date.year,
        appointment.date.month,
        appointment.date.day,
      );
      events.putIfAbsent(day, () => []).add(appointment);
    }

    final selectedKey = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final selectedItems = events[selectedKey] ?? const <AppointmentItem>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GKCard(
          padding: const EdgeInsets.all(10),
          child: TableCalendar<AppointmentItem>(
            locale: localeFromLanguage(language),
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return events[key] ?? const <AppointmentItem>[];
            },
            calendarFormat: CalendarFormat.month,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: GKColors.primary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: GKColors.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: GKColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${t('appointments_for_date')} ${DateFormat('dd/MM/yyyy').format(_selectedDay)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (selectedItems.isEmpty)
          GKCard(child: Text(t('appointments_empty_day')))
        else
          ...selectedItems.map((item) => _appointmentCard(item, t)),
      ],
    );
  }

  Widget _appointmentCard(
    AppointmentItem item,
    String Function(String key) t,
  ) {
    final badge = switch (item.status) {
      'completed' => (
          label: t('appointments_status_completed'),
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        ),
      'confirmed' => (
          label: t('appointments_status_confirmed'),
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        ),
      'in_progress' => (
          label: t('appointments_status_in_progress'),
          background: Color(0xFFE8F4F8),
          foreground: GKColors.primary,
        ),
      'pending' => (
          label: t('appointments_status_pending'),
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFF92400E),
        ),
      'cancelled' => (
          label: t('appointments_status_cancelled'),
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        ),
      'rescheduled' => (
          label: t('appointments_status_rescheduled'),
          background: Color(0xFFEDE9FE),
          foreground: Color(0xFF5B21B6),
        ),
      _ => (
          label: t('appointments_status_in_progress'),
          background: Color(0xFFE8F4F8),
          foreground: GKColors.primary,
        ),
    };

    return GestureDetector(
      onTap: () => context.push('/patients/${item.patientId}'),
      child: GKCard(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            GKAvatar(
              name: item.patientName.isEmpty
                  ? t('patient_default')
                  : item.patientName,
              imageUrl: item.patientAvatarUrl.isNotEmpty
                  ? item.patientAvatarUrl
                  : (item.professionalAvatarUrl.isNotEmpty
                      ? item.professionalAvatarUrl
                      : null),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.patientName.isEmpty
                        ? t('preop_patient_without_name')
                        : item.patientName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.specialtyName.isEmpty
                        ? _appointmentTypeLabel(item.type, t)
                        : item.specialtyName,
                    style: const TextStyle(color: GKColors.neutral),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDate(item.date)} - ${item.time.length >= 5 ? item.time.substring(0, 5) : item.time}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            GKBadge(
              label: badge.label,
              background: badge.background,
              foreground: badge.foreground,
            ),
          ],
        ),
      ),
    );
  }

  String _appointmentTypeLabel(
    String rawType,
    String Function(String key) t,
  ) {
    switch (rawType) {
      case 'first_visit':
        return t('appointments_type_first_visit');
      case 'return':
        return t('appointments_type_return');
      case 'surgery':
        return t('appointments_type_surgery');
      case 'post_op_7d':
        return t('appointments_type_post_op_7d');
      case 'post_op_30d':
        return t('appointments_type_post_op_30d');
      case 'post_op_90d':
        return t('appointments_type_post_op_90d');
      default:
        return t('appointments_type_unknown');
    }
  }

  bool _matchesStatusFilter(
    AppointmentItem item,
    AppointmentStatusFilterChip filter,
  ) {
    switch (filter) {
      case AppointmentStatusFilterChip.all:
        return true;
      case AppointmentStatusFilterChip.pending:
        return item.status == 'pending';
      case AppointmentStatusFilterChip.confirmed:
        return item.status == 'confirmed';
      case AppointmentStatusFilterChip.inProgress:
        return item.status == 'in_progress';
      case AppointmentStatusFilterChip.completed:
        return item.status == 'completed';
      case AppointmentStatusFilterChip.cancelled:
        return item.status == 'cancelled';
      case AppointmentStatusFilterChip.rescheduled:
        return item.status == 'rescheduled';
    }
  }

  Widget _chip(String label, AppointmentStatusFilterChip value) {
    final active = _statusFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _statusFilter = value),
        selectedColor: GKColors.primary,
        backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
        labelStyle: TextStyle(
          color: active ? Colors.white : onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
