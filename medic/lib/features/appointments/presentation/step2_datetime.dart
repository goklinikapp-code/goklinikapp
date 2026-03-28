import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import 'appointments_controller.dart';

class AppointmentStep2DateTimeScreen extends ConsumerStatefulWidget {
  const AppointmentStep2DateTimeScreen({super.key});

  @override
  ConsumerState<AppointmentStep2DateTimeScreen> createState() => _AppointmentStep2DateTimeScreenState();
}

class _AppointmentStep2DateTimeScreenState extends ConsumerState<AppointmentStep2DateTimeScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  String? _selectedProfessional;
  bool _loading = false;
  String? _error;
  List<String> _slots = const [];

  final List<_ProfessionalItem> _defaultProfessionals = [
    _ProfessionalItem(
      id: dotenv.env['DEFAULT_PROFESSIONAL_ID'] ?? '',
      name: dotenv.env['DEFAULT_PROFESSIONAL_NAME'] ?? 'Equipe Clínica',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final firstId = _defaultProfessionals.first.id;
    if (firstId.isNotEmpty) {
      _selectedProfessional = firstId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSlots());
    }
  }

  Future<void> _loadSlots() async {
    if (_selectedProfessional == null || _selectedProfessional!.isEmpty) {
      setState(() {
        _slots = [];
        _error = 'A clínica precisa configurar um profissional padrão para liberar horários.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _selectedTime = null;
    });

    try {
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final specialtyId = GoRouterState.of(context).uri.queryParameters['specialty_id'];
      final slots = await ref.read(appointmentsControllerProvider.notifier).fetchSlots(
            professionalId: _selectedProfessional!,
            date: date,
            specialtyId: specialtyId,
          );

      setState(() {
        _slots = slots;
        if (_slots.isEmpty) {
          _error = 'Sem horários disponíveis para este dia.';
        }
      });
    } catch (_) {
      setState(() {
        _slots = [];
        _error = 'Não foi possível carregar horários agora.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = GoRouterState.of(context).uri.queryParameters;
    final specialtyName = query['specialty_name'] ?? 'Especialidade';

    return Scaffold(
      appBar: AppBar(title: const Text('Novo Agendamento')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'PASSO 02 DE 04',
                  style: TextStyle(
                    color: GKColors.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Escolha data e horário', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('Especialidade: $specialtyName'),
                const SizedBox(height: 16),
                GKCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Profissional designado', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedProfessional,
                        decoration: const InputDecoration(labelText: 'Profissional'),
                        items: _defaultProfessionals
                            .where((item) => item.id.isNotEmpty)
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedProfessional = value);
                          _loadSlots();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 14,
                    itemBuilder: (context, index) {
                      final day = DateTime.now().add(Duration(days: index + 1));
                      final selected = DateUtils.isSameDay(day, _selectedDate);
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedDate = day);
                          _loadSlots();
                        },
                        child: Container(
                          width: 68,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: selected ? GKColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('EEE', 'pt_BR').format(day).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selected ? Colors.white70 : GKColors.neutral,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('dd').format(day),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : GKColors.darkBackground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (!_loading)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _slots.map((slot) {
                      final selected = slot == _selectedTime;
                      return ChoiceChip(
                        label: Text(slot),
                        selected: selected,
                        selectedColor: GKColors.primary,
                        labelStyle: TextStyle(color: selected ? Colors.white : GKColors.darkBackground),
                        onSelected: (_) => setState(() => _selectedTime = slot),
                      );
                    }).toList(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: const TextStyle(color: GKColors.danger)),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GKButton(
                label: 'Próximo',
                onPressed: (_selectedTime == null || _selectedProfessional == null)
                    ? null
                    : () {
                        final query = {
                          'specialty_id': GoRouterState.of(context).uri.queryParameters['specialty_id'] ?? '',
                          'specialty_name': specialtyName,
                          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
                          'time': _selectedTime!,
                          'professional_id': _selectedProfessional!,
                          'professional_name': _defaultProfessionals
                              .firstWhere(
                                (item) => item.id == _selectedProfessional,
                                orElse: () => const _ProfessionalItem(id: '', name: 'Equipe Clínica'),
                              )
                              .name,
                        };

                        context.push(Uri(path: '/appointments/new/step3', queryParameters: query).toString());
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalItem {
  const _ProfessionalItem({required this.id, required this.name});

  final String id;
  final String name;
}
