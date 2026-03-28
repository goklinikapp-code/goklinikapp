import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../domain/appointment_models.dart';
import 'appointments_controller.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  bool _calendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final appointmentsState = ref.watch(appointmentsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _calendarView = !_calendarView),
            icon: Icon(_calendarView ? Icons.view_list : Icons.calendar_month),
            tooltip: _calendarView ? 'Modo lista' : 'Modo calendario',
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
        error: (error, _) =>
            Center(child: Text('Erro ao carregar agenda: $error')),
        data: (appointments) {
          if (_calendarView) {
            return _calendarMode(appointments);
          }
          return _listMode(appointments);
        },
      ),
    );
  }

  Widget _listMode(List<AppointmentItem> appointments) {
    if (appointments.isEmpty) {
      return const Center(
          child: Text('Sem agendamentos para este profissional.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final item = appointments[index];
        return _appointmentCard(item);
      },
    );
  }

  Widget _calendarMode(List<AppointmentItem> appointments) {
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
            locale: 'pt_BR',
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
          'Agendamentos de ${DateFormat('dd/MM/yyyy').format(_selectedDay)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (selectedItems.isEmpty)
          const GKCard(child: Text('Nenhum agendamento para este dia.'))
        else
          ...selectedItems.map(_appointmentCard),
      ],
    );
  }

  Widget _appointmentCard(AppointmentItem item) {
    final badge = switch (item.status) {
      'confirmed' => const (
          label: 'Confirmado',
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        ),
      'pending' => const (
          label: 'Aguardando',
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFF92400E),
        ),
      'cancelled' => const (
          label: 'Cancelado',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        ),
      _ => const (
          label: 'Em andamento',
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
                name: item.patientName.isEmpty ? 'Paciente' : item.patientName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.patientName.isEmpty
                        ? 'Paciente sem nome'
                        : item.patientName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.specialtyName.isEmpty
                        ? _appointmentTypeLabel(item.type)
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

  String _appointmentTypeLabel(String rawType) {
    switch (rawType) {
      case 'first_visit':
        return 'Primeira Consulta';
      case 'return':
        return 'Retorno';
      case 'surgery':
        return 'Cirurgia';
      case 'post_op_7d':
        return 'Pos-op 7 dias';
      case 'post_op_30d':
        return 'Pos-op 30 dias';
      case 'post_op_90d':
        return 'Pos-op 90 dias';
      default:
        return rawType;
    }
  }
}
