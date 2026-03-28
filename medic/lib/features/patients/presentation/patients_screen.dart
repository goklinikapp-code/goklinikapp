import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../domain/patient_models.dart';
import 'patients_controller.dart';

enum PatientsFilterChip {
  all,
  scheduled,
  recovering,
  recovered,
  special,
}

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _searchController = TextEditingController();
  PatientsFilterChip _filter = PatientsFilterChip.all;
  bool _searchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patientsState = ref.watch(myPatientsProvider);
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Buscar paciente por nome',
                  border: InputBorder.none,
                ),
              )
            : const Text('Pacientes'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                if (_searchVisible) {
                  _searchController.clear();
                }
                _searchVisible = !_searchVisible;
              });
            },
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
          ),
          IconButton(
            onPressed: () => ref.invalidate(myPatientsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('Todos', PatientsFilterChip.all),
                _chip('Agendados', PatientsFilterChip.scheduled),
                _chip('Em recuperacao', PatientsFilterChip.recovering),
                _chip('Recuperados', PatientsFilterChip.recovered),
                _chip('Casos especiais', PatientsFilterChip.special),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: patientsState.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: 8,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const GKLoadingShimmer(height: 88),
              ),
              error: (error, _) => Center(
                child: Text('Erro ao carregar pacientes: $error'),
              ),
              data: (items) {
                final filtered = items.where((patient) {
                  final matchesChip = _matchesFilter(patient, _filter);
                  final matchesQuery = query.isEmpty
                      ? true
                      : patient.fullName.toLowerCase().contains(query);
                  return matchesChip && matchesQuery;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Nenhum paciente encontrado para este filtro.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final patient = filtered[index];
                    final statusVisual = _statusVisual(patient.medicStatus);

                    return GestureDetector(
                      onTap: () => context.push('/patients/${patient.id}'),
                      child: GKCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            GKAvatar(
                              name: patient.fullName,
                              imageUrl: patient.avatarUrl,
                              radius: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patient.fullName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    patient.specialtyName.isNotEmpty
                                        ? patient.specialtyName
                                        : (patient.dateJoined != null
                                            ? 'Data da cirurgia: ${formatDate(patient.dateJoined!)}'
                                            : 'Sem procedimento informado'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: GKColors.neutral,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GKBadge(
                              label: statusVisual.label,
                              background: statusVisual.background,
                              foreground: statusVisual.foreground,
                            ),
                            if (patient.medicStatus == MedicPatientStatus.specialCase)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: GKColors.danger,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(MedicPatient patient, PatientsFilterChip filter) {
    switch (filter) {
      case PatientsFilterChip.all:
        return true;
      case PatientsFilterChip.scheduled:
        return patient.medicStatus == MedicPatientStatus.scheduled ||
            patient.medicStatus == MedicPatientStatus.preOp;
      case PatientsFilterChip.recovering:
        return patient.medicStatus == MedicPatientStatus.recovering;
      case PatientsFilterChip.recovered:
        return patient.medicStatus == MedicPatientStatus.recovered;
      case PatientsFilterChip.special:
        return patient.medicStatus == MedicPatientStatus.specialCase;
    }
  }

  _PatientStatusVisual _statusVisual(MedicPatientStatus status) {
    return switch (status) {
      MedicPatientStatus.scheduled => const _PatientStatusVisual(
          label: 'Agendado',
          background: Color(0xFFE4EDFF),
          foreground: Color(0xFF1D4ED8),
        ),
      MedicPatientStatus.preOp => const _PatientStatusVisual(
          label: 'Pre-op',
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFFB45309),
        ),
      MedicPatientStatus.recovering => const _PatientStatusVisual(
          label: 'Em recuperacao',
          background: Color(0xFFFFE5D0),
          foreground: Color(0xFFC2410C),
        ),
      MedicPatientStatus.recovered => const _PatientStatusVisual(
          label: 'Recuperado',
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        ),
      MedicPatientStatus.specialCase => const _PatientStatusVisual(
          label: 'Caso especial',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        ),
      MedicPatientStatus.inactive => const _PatientStatusVisual(
          label: 'Inativo',
          background: Color(0xFFE5E7EB),
          foreground: Color(0xFF4B5563),
        ),
    };
  }

  Widget _chip(String label, PatientsFilterChip value) {
    final active = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: GKColors.primary,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: active ? Colors.white : GKColors.darkBackground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PatientStatusVisual {
  const _PatientStatusVisual({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}
