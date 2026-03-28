import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import 'appointments_controller.dart';

class AppointmentStep3ConfirmScreen extends ConsumerStatefulWidget {
  const AppointmentStep3ConfirmScreen({super.key});

  @override
  ConsumerState<AppointmentStep3ConfirmScreen> createState() =>
      _AppointmentStep3ConfirmScreenState();
}

class _AppointmentStep3ConfirmScreenState
    extends ConsumerState<AppointmentStep3ConfirmScreen> {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final _notesController = TextEditingController();
  bool _submitting = false;
  bool _notesPrefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_notesPrefilled) return;
    _notesPrefilled = true;

    final initialNotes =
        (GoRouterState.of(context).uri.queryParameters['notes'] ?? '').trim();
    if (initialNotes.isNotEmpty) {
      _notesController.text = initialNotes;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = GoRouterState.of(context).uri.queryParameters;
    final specialtyName = query['specialty_name'] ?? 'Especialidade';
    final date = query['date'] ?? '';
    final time = query['time'] ?? '';
    final appointmentId = _normalizeNonEmpty(query['appointment_id']);
    final isReschedule = appointmentId != null;
    final professionalId = query['professional_id'] ?? '';
    final professionalName = query['professional_name'] ?? 'Equipe Clínica';
    final clinicLocation =
        query['clinic_location'] ?? 'Unidade principal da clínica';
    final specialtyId = query['specialty_id'] ?? '';
    final normalizedSpecialtyId = _normalizeUuid(specialtyId);
    final appointmentType = _normalizeNonEmpty(query['appointment_type']) ??
        'first_visit';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isReschedule ? 'Confirmar Reagendamento' : 'Confirmar Agendamento',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'PASSO 04 DE 04',
            style: TextStyle(
              color: GKColors.accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text('Confirmação', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          GKCard(
            color: GKColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RESUMO DA CONSULTA',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                ),
                const SizedBox(height: 8),
                Text(
                  specialtyName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GKCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GKAvatar(name: professionalName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(professionalName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          const Text('4.9 • 198 avaliações'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _dataBox('DATA', date)),
                    const SizedBox(width: 10),
                    Expanded(child: _dataBox('HORÁRIO', time)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Tipo de Consulta: ${_appointmentTypeLabel(appointmentType)}',
                ),
                const SizedBox(height: 4),
                Text('Localização: $clinicLocation'),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 4,
                  cursorColor: GKColors.primary,
                  style: const TextStyle(color: GKColors.darkBackground),
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    hintText:
                        'Ex: Alergias, sintomas específicos ou histórico relevante.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GKButton(
            label:
                isReschedule ? 'Confirmar Reagendamento' : 'Confirmar Agendamento',
            isLoading: _submitting,
            onPressed: professionalId.isEmpty || date.isEmpty || time.isEmpty
                ? null
                : () => _submit(
                      appointmentId: appointmentId,
                      professionalId: professionalId,
                      specialtyId: normalizedSpecialtyId,
                      clinicLocation: clinicLocation,
                      appointmentType: appointmentType,
                      date: date,
                      time: time,
                    ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Revisar informações'),
          ),
        ],
      ),
    );
  }

  Widget _dataBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GKColors.tealIce,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 10,
                  color: GKColors.neutral,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<void> _submit({
    String? appointmentId,
    required String professionalId,
    String? specialtyId,
    String? clinicLocation,
    required String appointmentType,
    required String date,
    required String time,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    setState(() => _submitting = true);
    try {
      final result = appointmentId != null
          ? await ref
              .read(appointmentsControllerProvider.notifier)
              .rescheduleAppointment(
                appointmentId: appointmentId,
                professionalId: professionalId,
                specialtyId: specialtyId,
                clinicLocation: clinicLocation,
                appointmentType: appointmentType,
                date: date,
                time: time,
                notes: _notesController.text.trim(),
              )
          : await ref
              .read(appointmentsControllerProvider.notifier)
              .createAppointment(
                professionalId: professionalId,
                specialtyId: specialtyId,
                clinicLocation: clinicLocation,
                appointmentType: appointmentType,
                date: date,
                time: time,
                notes: _notesController.text.trim(),
              );

      if (!mounted) return;

      if (result == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              appointmentId != null
                  ? 'Não foi possível reagendar a consulta.'
                  : 'Não foi possível criar o agendamento.',
            ),
          ),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            appointmentId != null
                ? 'Agendamento reagendado para ${formatDate(result.date)} às ${result.time}.'
                : 'Agendamento confirmado para ${formatDate(result.date)} às ${result.time}.',
          ),
        ),
      );
      router.go('/agendas');
    } catch (error) {
      if (!mounted) return;
      String message = appointmentId != null
          ? 'Falha ao reagendar consulta. Verifique os dados da clínica.'
          : 'Falha ao confirmar agendamento. Verifique os dados da clínica.';
      if (error is DioException) {
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        if (statusCode == 409) {
          message = 'Esse horário acabou de ser reservado. Escolha outro.';
        } else if (responseData is Map<String, dynamic>) {
          final detail = responseData['detail'];
          if (detail is String && detail.trim().isNotEmpty) {
            message = detail;
          }
        }
      }
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String? _normalizeUuid(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) return null;
    return _uuidRegex.hasMatch(normalized) ? normalized : null;
  }

  String? _normalizeNonEmpty(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _appointmentTypeLabel(String value) {
    switch (value) {
      case 'follow_up':
        return 'Retorno';
      case 'surgery':
        return 'Cirurgia';
      case 'evaluation':
        return 'Avaliação';
      case 'first_visit':
      default:
        return 'Primeira Vez';
    }
  }
}
