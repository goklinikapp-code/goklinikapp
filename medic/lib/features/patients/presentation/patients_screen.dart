import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notification_bell_action.dart';
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
  String? _updatingUrgentTicketId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'Agora';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours} h';
    return 'Há ${diff.inDays} d';
  }

  _PatientStatusVisual _urgentStatusVisual(String status) {
    switch (status) {
      case 'resolved':
        return const _PatientStatusVisual(
          label: 'Resolvido',
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case 'viewed':
        return const _PatientStatusVisual(
          label: 'Visualizado',
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFFB45309),
        );
      default:
        return const _PatientStatusVisual(
          label: 'Aberto',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        );
    }
  }

  Future<void> _showUrgentTicketSheet(UrgentTicketItem ticket) async {
    final statusVisual = _urgentStatusVisual(ticket.status);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ticket.patientName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  GKBadge(
                    label: statusVisual.label,
                    background: statusVisual.background,
                    foreground: statusVisual.foreground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatRelativeTime(ticket.createdAt),
                    style: const TextStyle(
                      color: GKColors.neutral,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ticket.message,
                style: const TextStyle(fontSize: 14),
              ),
              if (ticket.images.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Imagens anexadas',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: GKColors.darkBackground,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ticket.images
                      .map(
                        (url) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              if (ticket.status != 'resolved')
                Row(
                  children: [
                    if (ticket.status == 'open')
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _updatingUrgentTicketId == ticket.id
                              ? null
                              : () async {
                                  setState(() =>
                                      _updatingUrgentTicketId = ticket.id);
                                  try {
                                    await ref
                                        .read(urgentTicketsProvider.notifier)
                                        .updateStatus(
                                          ticketId: ticket.id,
                                          status: 'viewed',
                                        );
                                    if (!mounted) {
                                      return;
                                    }
                                    Navigator.of(this.context).pop();
                                  } finally {
                                    if (mounted) {
                                      setState(
                                          () => _updatingUrgentTicketId = null);
                                    }
                                  }
                                },
                          child: const Text('Marcar visualizado'),
                        ),
                      ),
                    if (ticket.status == 'open') const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _updatingUrgentTicketId == ticket.id
                            ? null
                            : () async {
                                setState(
                                    () => _updatingUrgentTicketId = ticket.id);
                                try {
                                  await ref
                                      .read(urgentTicketsProvider.notifier)
                                      .updateStatus(
                                        ticketId: ticket.id,
                                        status: 'resolved',
                                      );
                                  if (!mounted) {
                                    return;
                                  }
                                  Navigator.of(this.context).pop();
                                } finally {
                                  if (mounted) {
                                    setState(
                                        () => _updatingUrgentTicketId = null);
                                  }
                                }
                              },
                        child: const Text('Resolver'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientsState = ref.watch(myPatientsProvider);
    final urgentTicketsState = ref.watch(urgentTicketsProvider);
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
          const NotificationBellAction(),
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
            onPressed: () {
              ref.invalidate(myPatientsProvider);
              ref.invalidate(urgentTicketsProvider);
            },
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: urgentTicketsState.when(
              loading: () => const GKLoadingShimmer(height: 86),
              error: (_, __) => GKCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Não foi possível carregar alertas urgentes.',
                        style: TextStyle(color: GKColors.neutral),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(urgentTicketsProvider.notifier).load(),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
              data: (tickets) {
                final unresolved = tickets
                    .where((ticket) => ticket.status != 'resolved')
                    .toList();
                if (unresolved.isEmpty) {
                  return const SizedBox.shrink();
                }
                final preview = unresolved.take(3).toList();
                return GKCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.notification_important_outlined,
                            color: GKColors.danger,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Alertas urgentes (${unresolved.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...preview.map((ticket) {
                        final statusVisual = _urgentStatusVisual(ticket.status);
                        return InkWell(
                          onTap: () => _showUrgentTicketSheet(ticket),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: GKColors.accent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ticket.patientName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        ticket.message,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: GKColors.neutral,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    GKBadge(
                                      label: statusVisual.label,
                                      background: statusVisual.background,
                                      foreground: statusVisual.foreground,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatRelativeTime(ticket.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: GKColors.neutral,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
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
                    final preOperatoryStatusVisual =
                        patient.preOperatoryStatus == null
                            ? null
                            : _preOperatoryStatusVisual(
                                patient.preOperatoryStatus!,
                              );

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
                                        : 'Sem procedimento informado',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: GKColors.neutral,
                                    ),
                                  ),
                                  if (preOperatoryStatusVisual != null) ...[
                                    const SizedBox(height: 6),
                                    GKBadge(
                                      label: preOperatoryStatusVisual.label,
                                      background:
                                          preOperatoryStatusVisual.background,
                                      foreground:
                                          preOperatoryStatusVisual.foreground,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GKBadge(
                              label: statusVisual.label,
                              background: statusVisual.background,
                              foreground: statusVisual.foreground,
                            ),
                            if (patient.medicStatus ==
                                MedicPatientStatus.specialCase)
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
        return patient.medicStatus == MedicPatientStatus.scheduled;
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

  _PatientStatusVisual _preOperatoryStatusVisual(PreOperatoryStatus status) {
    return switch (status) {
      PreOperatoryStatus.pending => const _PatientStatusVisual(
          label: 'Pre-op pendente',
          background: Color(0xFFE2E8F0),
          foreground: Color(0xFF334155),
        ),
      PreOperatoryStatus.inReview => const _PatientStatusVisual(
          label: 'Pre-op em analise',
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFFB45309),
        ),
      PreOperatoryStatus.approved => const _PatientStatusVisual(
          label: 'Pre-op aprovado',
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        ),
      PreOperatoryStatus.rejected => const _PatientStatusVisual(
          label: 'Pre-op reprovado',
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
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
