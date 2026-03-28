import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import 'appointments_controller.dart';

class AppointmentStep3ConfirmScreen extends ConsumerStatefulWidget {
  const AppointmentStep3ConfirmScreen({super.key});

  @override
  ConsumerState<AppointmentStep3ConfirmScreen> createState() => _AppointmentStep3ConfirmScreenState();
}

class _AppointmentStep3ConfirmScreenState extends ConsumerState<AppointmentStep3ConfirmScreen> {
  final _notesController = TextEditingController();
  bool _submitting = false;

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
    final professionalId = query['professional_id'] ?? '';
    final professionalName = query['professional_name'] ?? 'Equipe Clínica';
    final specialtyId = query['specialty_id'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar Agendamento')),
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
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Text(
                  specialtyName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
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
                          Text(professionalName, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                const Text('Tipo de Consulta: Primeira Vez'),
                const SizedBox(height: 4),
                const Text('Localização: Unidade principal da clínica'),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 4,
                  cursorColor: GKColors.primary,
                  style: const TextStyle(color: GKColors.darkBackground),
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    hintText: 'Ex: Alergias, sintomas específicos ou histórico relevante.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GKButton(
            label: 'Confirmar Agendamento',
            isLoading: _submitting,
            onPressed: professionalId.isEmpty || date.isEmpty || time.isEmpty
                ? null
                : () => _submit(
                      professionalId: professionalId,
                      specialtyId: specialtyId,
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
          Text(title, style: const TextStyle(fontSize: 10, color: GKColors.neutral, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<void> _submit(
    {
    required String professionalId,
    required String specialtyId,
    required String date,
    required String time,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    setState(() => _submitting = true);
    try {
      final result = await ref.read(appointmentsControllerProvider.notifier).createAppointment(
            professionalId: professionalId,
            specialtyId: specialtyId.isEmpty ? null : specialtyId,
            date: date,
            time: time,
            notes: _notesController.text.trim(),
          );

      if (!mounted) return;

      if (result == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Não foi possível criar o agendamento.')),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Agendamento confirmado para ${formatDate(result.date)} às ${result.time}.',
          ),
        ),
      );
      router.go('/agendas');
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Falha ao confirmar agendamento. Verifique os dados da clínica.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
