import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../../../core/widgets/notification_bell_action.dart';
import '../../appointments/domain/appointment_models.dart';
import '../../auth/presentation/auth_controller.dart';
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

  String _t(String key) {
    final language = ref.read(appPreferencesControllerProvider).language;
    return appTr(key: key, language: language);
  }

  String _formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return _t('relative_now');
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return _t('relative_now');
    if (diff.inMinutes < 60) {
      return '${_t('relative_ago_prefix')} ${diff.inMinutes} ${_t('relative_minutes_short')}';
    }
    if (diff.inHours < 24) {
      return '${_t('relative_ago_prefix')} ${diff.inHours} ${_t('relative_hours_short')}';
    }
    return '${_t('relative_ago_prefix')} ${diff.inDays} ${_t('relative_days_short')}';
  }

  _PatientStatusVisual _urgentStatusVisual(String status) {
    switch (status) {
      case 'resolved':
        return _PatientStatusVisual(
          label: _t('urgent_status_resolved'),
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case 'viewed':
        return _PatientStatusVisual(
          label: _t('urgent_status_viewed'),
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFFB45309),
        );
      default:
        return _PatientStatusVisual(
          label: _t('urgent_status_open'),
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
                Text(
                  _t('urgent_images_attached'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
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
                                  setState(() {
                                    _updatingUrgentTicketId = ticket.id;
                                  });
                                  try {
                                    await ref
                                        .read(urgentTicketsProvider.notifier)
                                        .updateStatus(
                                          ticketId: ticket.id,
                                          status: 'viewed',
                                        );
                                    if (!mounted) return;
                                    Navigator.of(this.context).pop();
                                  } finally {
                                    if (mounted) {
                                      setState(
                                          () => _updatingUrgentTicketId = null);
                                    }
                                  }
                                },
                          child: Text(_t('urgent_mark_viewed')),
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
                                  if (!mounted) return;
                                  Navigator.of(this.context).pop();
                                } finally {
                                  if (mounted) {
                                    setState(
                                        () => _updatingUrgentTicketId = null);
                                  }
                                }
                              },
                        child: Text(_t('urgent_resolve')),
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

  Future<void> _showAppointmentSheet(_PatientListEntry entry) async {
    final appointment = entry.appointment;
    if (appointment == null) {
      if (entry.patientId.isNotEmpty) {
        context.push('/patients/${entry.patientId}');
      }
      return;
    }

    final procedureLabel = appointment.specialtyName.trim().isNotEmpty
        ? appointment.specialtyName.trim()
        : _appointmentTypeLabel(appointment.type);
    final dateLabel = formatDate(appointment.date);
    final timeLabel = appointment.time.length >= 5
        ? appointment.time.substring(0, 5)
        : appointment.time;
    final statusVisual = _appointmentStatusVisual(appointment.status);

    final shouldOpenPatient = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.patientName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                GKBadge(
                  label: statusVisual.label,
                  background: statusVisual.background,
                  foreground: statusVisual.foreground,
                ),
                const SizedBox(height: 16),
                _AppointmentInfoRow(
                  label: _t('appointment_info_procedure'),
                  value: procedureLabel,
                ),
                const SizedBox(height: 10),
                _AppointmentInfoRow(
                  label: _t('appointment_info_date_time'),
                  value: timeLabel.isEmpty
                      ? dateLabel
                      : '$dateLabel às $timeLabel',
                ),
                if (appointment.clinicLocation.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _AppointmentInfoRow(
                    label: _t('appointment_info_location'),
                    value: appointment.clinicLocation.trim(),
                  ),
                ],
                if (appointment.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _AppointmentInfoRow(
                    label: _t('appointment_info_notes'),
                    value: appointment.notes.trim(),
                  ),
                ],
                const SizedBox(height: 18),
                if (entry.patientId.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop(true);
                      },
                      icon: const Icon(Icons.person_outline),
                      label: Text(_t('appointment_view_patient_details')),
                    ),
                  ),
                if (entry.patientId.isNotEmpty) const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(_t('chat_close')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (shouldOpenPatient == true && entry.patientId.isNotEmpty) {
      context.push('/patients/${entry.patientId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsState = ref.watch(myPatientsProvider);
    final urgentTicketsState = ref.watch(urgentTicketsProvider);
    final activeAppointmentsState = ref.watch(myActiveAppointmentsProvider);
    final session = ref.watch(authControllerProvider).session;
    final surgeonId =
        session?.user.role == 'surgeon' ? (session?.user.id ?? '') : null;
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _t('patients_search_hint'),
                  border: InputBorder.none,
                ),
              )
            : Text(_t('patients_title')),
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
              ref.invalidate(myActiveAppointmentsProvider);
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
                _chip(_t('appointments_filter_all'), PatientsFilterChip.all),
                _chip(_t('patients_filter_scheduled'),
                    PatientsFilterChip.scheduled),
                _chip(_t('patients_filter_recovering'),
                    PatientsFilterChip.recovering),
                _chip(_t('patients_filter_recovered'),
                    PatientsFilterChip.recovered),
                _chip(
                    _t('patients_filter_special'), PatientsFilterChip.special),
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
                    Expanded(
                      child: Text(
                        _t('urgent_load_error'),
                        style: const TextStyle(color: GKColors.neutral),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(urgentTicketsProvider.notifier).load(),
                      child: Text(_t('try_again')),
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
                            '${_t('urgent_alerts')} (${unresolved.length})',
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
                child: Text('${_t('patients_load_error_prefix')}: $error'),
              ),
              data: (items) {
                final maybeActiveAppointments =
                    activeAppointmentsState.maybeWhen(
                  data: (value) => value,
                  orElse: () => null,
                );
                final activeAppointments =
                    maybeActiveAppointments ?? const <AppointmentItem>[];
                final appointmentByPatientId =
                    _buildActiveAppointmentIndex(activeAppointments);
                final activeAppointmentPatientIds =
                    maybeActiveAppointments == null
                        ? null
                        : appointmentByPatientId.keys.toSet();
                final scopedPatients = surgeonId == null || surgeonId.isEmpty
                    ? items
                    : items
                        .where((patient) =>
                            patient.assignedDoctor?.id == surgeonId)
                        .toList();

                final entries = <_PatientListEntry>[
                  for (final patient in scopedPatients)
                    _PatientListEntry(
                      patient: patient,
                      appointment: appointmentByPatientId[patient.id],
                      status: appointmentByPatientId.containsKey(patient.id)
                          ? MedicPatientStatus.scheduled
                          : _effectiveStatus(
                              patient,
                              activeAppointmentPatientIds:
                                  activeAppointmentPatientIds,
                            ),
                    ),
                ];

                final filtered = entries.where((entry) {
                  final matchesChip = _matchesFilter(entry.status, _filter);
                  final matchesQuery = query.isEmpty
                      ? true
                      : entry.patientName.toLowerCase().contains(query);
                  return matchesChip && matchesQuery;
                }).toList()
                  ..sort(_sortEntries);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(_t('patients_empty_filtered')),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final statusVisual = _statusVisual(entry.status);
                    final preOperatoryStatusVisual = entry.preOperatoryStatus ==
                            null
                        ? null
                        : _preOperatoryStatusVisual(entry.preOperatoryStatus!);
                    final subtitle = entry.appointment != null
                        ? _appointmentSummary(entry.appointment!)
                        : (entry.patient?.specialtyName.trim().isNotEmpty ==
                                true
                            ? entry.patient!.specialtyName.trim()
                            : _t('patients_no_procedure_info'));

                    return GestureDetector(
                      onTap: () async {
                        if (entry.appointment != null) {
                          await _showAppointmentSheet(entry);
                          return;
                        }
                        if (entry.patientId.isNotEmpty) {
                          context.push('/patients/${entry.patientId}');
                        }
                      },
                      child: GKCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            GKAvatar(
                              name: entry.patientName,
                              imageUrl: entry.avatarUrl,
                              radius: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.patientName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: GKColors.neutral,
                                    ),
                                  ),
                                  if (entry.appointment != null &&
                                      entry.appointment!.clinicLocation
                                          .trim()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.appointment!.clinicLocation.trim(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: GKColors.neutral,
                                      ),
                                    ),
                                  ],
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
                            if (entry.status == MedicPatientStatus.specialCase)
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

  MedicPatientStatus _effectiveStatus(
    MedicPatient patient, {
    Set<String>? activeAppointmentPatientIds,
  }) {
    final hasDoctorSpecificActiveAppointment =
        activeAppointmentPatientIds?.contains(patient.id);
    final hasActiveAppointment =
        hasDoctorSpecificActiveAppointment ?? patient.hasActiveAppointment;
    return resolveMedicStatus(
      patient.rawStatus,
      patient.notes,
      hasActiveAppointment: hasActiveAppointment,
      hasCompletedSurgery: patient.hasCompletedSurgery,
      preOperatoryStatus: patient.preOperatoryStatus,
    );
  }

  Map<String, AppointmentItem> _buildActiveAppointmentIndex(
    List<AppointmentItem> appointments,
  ) {
    final index = <String, AppointmentItem>{};
    final now = DateTime.now();
    for (final appointment in appointments) {
      final patientId = appointment.patientId.trim();
      if (patientId.isEmpty) {
        continue;
      }

      final current = index[patientId];
      if (current == null ||
          _isBetterAppointment(
              candidate: appointment, current: current, now: now)) {
        index[patientId] = appointment;
      }
    }
    return index;
  }

  bool _isBetterAppointment({
    required AppointmentItem candidate,
    required AppointmentItem current,
    required DateTime now,
  }) {
    final candidateDate = candidate.dateTime;
    final currentDate = current.dateTime;
    final candidateIsFuture = !candidateDate.isBefore(now);
    final currentIsFuture = !currentDate.isBefore(now);

    if (candidateIsFuture != currentIsFuture) {
      return candidateIsFuture;
    }

    if (candidateIsFuture) {
      return candidateDate.isBefore(currentDate);
    }

    return candidateDate.isAfter(currentDate);
  }

  int _sortEntries(_PatientListEntry a, _PatientListEntry b) {
    final aScheduled = a.status == MedicPatientStatus.scheduled;
    final bScheduled = b.status == MedicPatientStatus.scheduled;
    if (aScheduled && bScheduled) {
      final aDate = a.appointment?.dateTime;
      final bDate = b.appointment?.dateTime;
      if (aDate != null && bDate != null) {
        return aDate.compareTo(bDate);
      }
      if (aDate != null) return -1;
      if (bDate != null) return 1;
      return a.patientName.toLowerCase().compareTo(b.patientName.toLowerCase());
    }

    if (aScheduled != bScheduled) {
      return aScheduled ? -1 : 1;
    }

    return a.patientName.toLowerCase().compareTo(b.patientName.toLowerCase());
  }

  String _appointmentSummary(AppointmentItem appointment) {
    final procedureLabel = appointment.specialtyName.trim().isNotEmpty
        ? appointment.specialtyName.trim()
        : _appointmentTypeLabel(appointment.type);
    final dateLabel = formatDate(appointment.date);
    final timeLabel = appointment.time.length >= 5
        ? appointment.time.substring(0, 5)
        : appointment.time;
    if (timeLabel.isEmpty) {
      return '$procedureLabel • $dateLabel';
    }
    return '$procedureLabel • $dateLabel às $timeLabel';
  }

  String _appointmentTypeLabel(String rawType) {
    switch (rawType) {
      case 'first_visit':
        return _t('appointments_type_first_visit');
      case 'return':
        return _t('appointments_type_return');
      case 'surgery':
        return _t('appointments_type_surgery');
      case 'post_op_7d':
        return _t('appointments_type_post_op_7d');
      case 'post_op_30d':
        return _t('appointments_type_post_op_30d');
      case 'post_op_90d':
        return _t('appointments_type_post_op_90d');
      default:
        return _t('appointments_type_unknown');
    }
  }

  _PatientStatusVisual _appointmentStatusVisual(String rawStatus) {
    switch (rawStatus) {
      case 'confirmed':
        return _PatientStatusVisual(
          label: _t('appointments_status_confirmed'),
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      case 'in_progress':
        return _PatientStatusVisual(
          label: _t('appointments_status_in_progress'),
          background: Color(0xFFE8F4F8),
          foreground: GKColors.primary,
        );
      case 'rescheduled':
        return _PatientStatusVisual(
          label: _t('appointments_status_rescheduled'),
          background: Color(0xFFEDE9FE),
          foreground: Color(0xFF5B21B6),
        );
      case 'pending':
        return _PatientStatusVisual(
          label: _t('appointments_status_pending'),
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFF92400E),
        );
      case 'cancelled':
        return _PatientStatusVisual(
          label: _t('appointments_status_cancelled'),
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        );
      case 'completed':
        return _PatientStatusVisual(
          label: _t('appointments_status_completed'),
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        );
      default:
        return _PatientStatusVisual(
          label: _t('patients_filter_scheduled'),
          background: Color(0xFFE4EDFF),
          foreground: Color(0xFF1D4ED8),
        );
    }
  }

  bool _matchesFilter(MedicPatientStatus status, PatientsFilterChip filter) {
    switch (filter) {
      case PatientsFilterChip.all:
        return true;
      case PatientsFilterChip.scheduled:
        return status == MedicPatientStatus.scheduled;
      case PatientsFilterChip.recovering:
        return status == MedicPatientStatus.recovering;
      case PatientsFilterChip.recovered:
        return status == MedicPatientStatus.recovered;
      case PatientsFilterChip.special:
        return status == MedicPatientStatus.specialCase;
    }
  }

  _PatientStatusVisual _statusVisual(MedicPatientStatus status) {
    return switch (status) {
      MedicPatientStatus.scheduled => _PatientStatusVisual(
          label: _t('patients_filter_scheduled'),
          background: Color(0xFFE4EDFF),
          foreground: Color(0xFF1D4ED8),
        ),
      MedicPatientStatus.preOp => _PatientStatusVisual(
          label: _t('quick_pre_operatory'),
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFFB45309),
        ),
      MedicPatientStatus.recovering => _PatientStatusVisual(
          label: _t('patients_filter_recovering'),
          background: Color(0xFFFFE5D0),
          foreground: Color(0xFFC2410C),
        ),
      MedicPatientStatus.recovered => _PatientStatusVisual(
          label: _t('patients_filter_recovered'),
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        ),
      MedicPatientStatus.specialCase => _PatientStatusVisual(
          label: _t('patients_filter_special'),
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        ),
      MedicPatientStatus.inactive => _PatientStatusVisual(
          label: _t('patient_status_inactive'),
          background: Color(0xFFE5E7EB),
          foreground: Color(0xFF4B5563),
        ),
    };
  }

  _PatientStatusVisual _preOperatoryStatusVisual(PreOperatoryStatus status) {
    return switch (status) {
      PreOperatoryStatus.pending => _PatientStatusVisual(
          label: _t('patients_preop_pending'),
          background: Color(0xFFE2E8F0),
          foreground: Color(0xFF334155),
        ),
      PreOperatoryStatus.inReview => _PatientStatusVisual(
          label: _t('patients_preop_in_review'),
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFFB45309),
        ),
      PreOperatoryStatus.approved => _PatientStatusVisual(
          label: _t('patients_preop_approved'),
          background: Color(0xFFDCFCE7),
          foreground: Color(0xFF166534),
        ),
      PreOperatoryStatus.rejected => _PatientStatusVisual(
          label: _t('patients_preop_rejected'),
          background: Color(0xFFFEE2E2),
          foreground: Color(0xFFB91C1C),
        ),
    };
  }

  Widget _chip(String label, PatientsFilterChip value) {
    final active = _filter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _filter = value),
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

class _PatientListEntry {
  const _PatientListEntry({
    required this.patient,
    required this.appointment,
    required this.status,
  });

  final MedicPatient? patient;
  final AppointmentItem? appointment;
  final MedicPatientStatus status;

  String get patientId {
    final idFromPatient = (patient?.id ?? '').trim();
    if (idFromPatient.isNotEmpty) {
      return idFromPatient;
    }
    return (appointment?.patientId ?? '').trim();
  }

  String get patientName {
    final patientName = (patient?.fullName ?? '').trim();
    if (patientName.isNotEmpty) {
      return patientName;
    }
    final appointmentName = (appointment?.patientName ?? '').trim();
    if (appointmentName.isNotEmpty) {
      return appointmentName;
    }
    return 'Paciente sem nome';
  }

  String? get avatarUrl {
    final patientAvatar = (patient?.avatarUrl ?? '').trim();
    if (patientAvatar.isNotEmpty) {
      return patientAvatar;
    }
    final appointmentAvatar = (appointment?.patientAvatarUrl ?? '').trim();
    if (appointmentAvatar.isNotEmpty) {
      return appointmentAvatar;
    }
    return null;
  }

  PreOperatoryStatus? get preOperatoryStatus => patient?.preOperatoryStatus;
}

class _AppointmentInfoRow extends StatelessWidget {
  const _AppointmentInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: GKColors.neutral,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
