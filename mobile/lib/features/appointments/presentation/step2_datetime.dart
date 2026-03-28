import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../branding/presentation/tenant_branding_controller.dart';
import 'appointments_controller.dart';

class AppointmentStep2DateTimeScreen extends ConsumerStatefulWidget {
  const AppointmentStep2DateTimeScreen({super.key});

  @override
  ConsumerState<AppointmentStep2DateTimeScreen> createState() =>
      _AppointmentStep2DateTimeScreenState();
}

class _AppointmentStep2DateTimeScreenState
    extends ConsumerState<AppointmentStep2DateTimeScreen> {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  String? _selectedProfessional;
  String? _selectedClinicLocation;
  String? _specialtyId;
  String _specialtyName = 'Especialidade';
  String? _rescheduleAppointmentId;
  String? _rescheduleAppointmentType;
  String? _initialNotes;
  bool _initializedFromRoute = false;
  bool _loadingSlots = false;
  bool _loadingProfessionals = false;
  bool _loadingDayAvailability = false;
  String? _error;
  List<String> _slots = const [];
  List<_ProfessionalItem> _professionals = const [];
  Map<String, bool> _dayHasAvailability = const {};

  final List<_ProfessionalItem> _defaultProfessionals = [
    _ProfessionalItem(
      id: dotenv.env['DEFAULT_PROFESSIONAL_ID'] ?? '',
      name: dotenv.env['DEFAULT_PROFESSIONAL_NAME'] ?? 'Equipe Clínica',
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromRoute) return;

    _initializedFromRoute = true;
    _hydrateFromRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfessionals());
  }

  void _hydrateFromRoute() {
    final query = GoRouterState.of(context).uri.queryParameters;
    _specialtyId = _normalizeUuid(query['specialty_id']);

    final rawSpecialtyName = (query['specialty_name'] ?? '').trim();
    _specialtyName = rawSpecialtyName.isEmpty ? 'Especialidade' : rawSpecialtyName;

    final initialDate = _parseDate(query['date']);
    if (initialDate != null) {
      _selectedDate = initialDate;
    }

    _selectedTime = _normalizeTime(query['time']);
    _selectedProfessional = _normalizeNonEmpty(query['professional_id']);
    _selectedClinicLocation = _normalizeNonEmpty(query['clinic_location']);
    _rescheduleAppointmentId = _normalizeNonEmpty(query['appointment_id']);
    _rescheduleAppointmentType = _normalizeNonEmpty(query['appointment_type']);
    _initialNotes = _normalizeNonEmpty(query['notes']);
  }

  Future<void> _loadProfessionals() async {
    final fallback =
        _defaultProfessionals.where((item) => item.id.isNotEmpty).toList();
    setState(() {
      _loadingProfessionals = true;
      _error = null;
    });

    try {
      final fetched = await ref
          .read(appointmentsControllerProvider.notifier)
          .fetchProfessionals();
      final mapped = fetched
          .where((item) => item.id.isNotEmpty)
          .map(
            (item) => _ProfessionalItem(
              id: item.id,
              name: item.name.isNotEmpty ? item.name : 'Equipe Clínica',
            ),
          )
          .toList();

      if (!mounted) return;

      final resolved = mapped.isNotEmpty ? mapped : fallback;
      final firstId = resolved.isNotEmpty ? resolved.first.id : null;

      setState(() {
        _professionals = resolved;
        if (_selectedProfessional == null ||
            !_professionals.any((item) => item.id == _selectedProfessional)) {
          _selectedProfessional = firstId;
        }
      });

      if (_selectedProfessional != null && _selectedProfessional!.isNotEmpty) {
        await _reloadAvailabilityAndSlots();
      } else {
        setState(() {
          _slots = [];
          _error = 'Nenhum profissional disponível para agendamento.';
          _dayHasAvailability = const {};
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _professionals = fallback;
        if (_selectedProfessional == null && _professionals.isNotEmpty) {
          _selectedProfessional = _professionals.first.id;
        }
      });

      if (_selectedProfessional != null && _selectedProfessional!.isNotEmpty) {
        await _reloadAvailabilityAndSlots();
      } else {
        setState(() {
          _slots = [];
          _error = 'Não foi possível carregar os profissionais agora.';
          _dayHasAvailability = const {};
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingProfessionals = false;
        });
      }
    }
  }

  List<DateTime> _upcomingDays() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final defaultEnd = tomorrow.add(const Duration(days: 13));
    final startDate = selectedDateOnly.isAfter(defaultEnd)
        ? selectedDateOnly
        : tomorrow;

    return List<DateTime>.generate(
      14,
      (index) => startDate.add(Duration(days: index)),
    );
  }

  String _dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _reloadAvailabilityAndSlots() async {
    await _loadDaysAvailability();
    await _loadSlots();
  }

  Future<void> _loadDaysAvailability() async {
    if (_selectedProfessional == null || _selectedProfessional!.isEmpty) {
      setState(() {
        _dayHasAvailability = const {};
      });
      return;
    }

    setState(() => _loadingDayAvailability = true);
    final days = _upcomingDays();
    final professionalId = _selectedProfessional!;
    final availabilityByDay = <String, bool>{};

    for (final day in days) {
      final date = _dayKey(day);
      try {
        final slots =
            await ref.read(appointmentsControllerProvider.notifier).fetchSlots(
                  professionalId: professionalId,
                  date: date,
                  specialtyId: _specialtyId,
                  appointmentId: _rescheduleAppointmentId,
                );
        availabilityByDay[date] = slots.isNotEmpty;
      } catch (_) {
        availabilityByDay[date] = false;
      }
    }

    if (!mounted) return;

    final selectedKey = _dayKey(_selectedDate);
    final selectedAvailable = availabilityByDay[selectedKey] ?? false;
    if (!selectedAvailable) {
      for (final day in days) {
        if (availabilityByDay[_dayKey(day)] == true) {
          _selectedDate = day;
          break;
        }
      }
    }

    setState(() {
      _dayHasAvailability = availabilityByDay;
      _loadingDayAvailability = false;
    });
  }

  Future<void> _loadSlots() async {
    if (_selectedProfessional == null || _selectedProfessional!.isEmpty) {
      setState(() {
        _slots = [];
        _error = 'Nenhum profissional disponível para agendamento.';
      });
      return;
    }

    setState(() {
      _loadingSlots = true;
      _error = null;
    });

    try {
      final previousSelection = _selectedTime;
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final slots =
          await ref.read(appointmentsControllerProvider.notifier).fetchSlots(
                professionalId: _selectedProfessional!,
                date: date,
                specialtyId: _specialtyId,
                appointmentId: _rescheduleAppointmentId,
              );

      setState(() {
        _slots = slots;
        _selectedTime =
            slots.contains(previousSelection) ? previousSelection : null;
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
          _loadingSlots = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tenantBranding = ref.watch(tenantBrandingProvider);
    final clinicLocations = tenantBranding.clinicAddresses.isNotEmpty
        ? tenantBranding.clinicAddresses
        : const ['Unidade principal da clínica'];
    final effectiveClinicLocation =
        (clinicLocations.contains(_selectedClinicLocation))
            ? (_selectedClinicLocation ?? clinicLocations.first)
            : clinicLocations.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _rescheduleAppointmentId == null
              ? 'Novo Agendamento'
              : 'Reagendar Consulta',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'PASSO 02 DE 04',
                  style: TextStyle(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Escolha data e horário',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('Especialidade: $_specialtyName'),
                const SizedBox(height: 16),
                GKCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Profissional designado',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedProfessional,
                        decoration:
                            const InputDecoration(labelText: 'Profissional'),
                        items: _professionals
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(),
                        onChanged: _professionals.isEmpty
                            ? null
                            : (value) {
                                setState(() => _selectedProfessional = value);
                                _reloadAvailabilityAndSlots();
                              },
                      ),
                      if (_loadingProfessionals)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: effectiveClinicLocation,
                        decoration: const InputDecoration(
                            labelText: 'Endereço da clínica'),
                        items: clinicLocations
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedClinicLocation = value);
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
                    itemCount: _upcomingDays().length,
                    itemBuilder: (context, index) {
                      final day = _upcomingDays()[index];
                      final hasAvailability = _dayHasAvailability[_dayKey(day)];
                      final selected = DateUtils.isSameDay(day, _selectedDate);
                      final backgroundColor = selected
                          ? colorScheme.primary
                          : (hasAvailability == true
                              ? const Color(0xFFDCFCE7)
                              : (hasAvailability == false
                                  ? const Color(0xFFFEE2E2)
                                  : Colors.white));
                      final borderColor = selected
                          ? colorScheme.primary
                          : (hasAvailability == true
                              ? const Color(0xFF86EFAC)
                              : (hasAvailability == false
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFE2E8F0)));
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedDate = day);
                          _loadSlots();
                        },
                        child: Container(
                          width: 68,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('EEE', 'pt_BR')
                                    .format(day)
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selected
                                      ? Colors.white70
                                      : (hasAvailability == false
                                          ? colorScheme.error
                                          : colorScheme.onSurfaceVariant),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('dd').format(day),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_loadingDayAvailability)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    _LegendDot(
                        color: Color(0xFFDCFCE7), border: Color(0xFF86EFAC)),
                    SizedBox(width: 6),
                    Text('Com horários', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 14),
                    _LegendDot(
                        color: Color(0xFFFEE2E2), border: Color(0xFFFCA5A5)),
                    SizedBox(width: 6),
                    Text('Sem horários', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                if (_loadingSlots)
                  const Center(child: CircularProgressIndicator()),
                if (!_loadingSlots)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _slots.map((slot) {
                      final selected = slot == _selectedTime;
                      return ChoiceChip(
                        label: Text(slot),
                        selected: selected,
                        selectedColor: colorScheme.primary,
                        labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : colorScheme.onSurface),
                        onSelected: (_) => setState(() => _selectedTime = slot),
                      );
                    }).toList(),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        style: TextStyle(color: colorScheme.error)),
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
                onPressed: (_selectedTime == null ||
                        _selectedProfessional == null)
                    ? null
                    : () {
                        final query = {
                          'specialty_id': _specialtyId ?? '',
                          'specialty_name': _specialtyName,
                          'date':
                              DateFormat('yyyy-MM-dd').format(_selectedDate),
                          'time': _selectedTime!,
                          'professional_id': _selectedProfessional!,
                          'clinic_location': effectiveClinicLocation,
                          'professional_name': _professionals
                              .firstWhere(
                                (item) => item.id == _selectedProfessional,
                                orElse: () => const _ProfessionalItem(
                                    id: '', name: 'Equipe Clínica'),
                              )
                              .name,
                          if (_rescheduleAppointmentId != null)
                            'appointment_id': _rescheduleAppointmentId!,
                          if (_rescheduleAppointmentType != null)
                            'appointment_type': _rescheduleAppointmentType!,
                          if (_initialNotes != null) 'notes': _initialNotes!,
                        };

                        query.removeWhere((_, value) => value.trim().isEmpty);
                        context.push(Uri(
                                path: '/appointments/new/step3',
                                queryParameters: query)
                            .toString());
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(String? rawDate) {
    final value = (rawDate ?? '').trim();
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String? _normalizeTime(String? rawTime) {
    final value = (rawTime ?? '').trim();
    if (value.isEmpty) return null;
    if (value.length >= 5 && value[2] == ':') {
      return value.substring(0, 5);
    }
    return value;
  }

  String? _normalizeNonEmpty(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _normalizeUuid(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) return null;
    return _uuidRegex.hasMatch(normalized) ? normalized : null;
  }
}

class _ProfessionalItem {
  const _ProfessionalItem({required this.id, required this.name});

  final String id;
  final String name;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.border,
  });

  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
    );
  }
}
