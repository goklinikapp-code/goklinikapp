import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_card.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/appointments_repository_impl.dart';
import '../domain/appointment_models.dart';

class DoctorAvailabilityScreen extends ConsumerStatefulWidget {
  const DoctorAvailabilityScreen({super.key});

  @override
  ConsumerState<DoctorAvailabilityScreen> createState() =>
      _DoctorAvailabilityScreenState();
}

class _DoctorAvailabilityScreenState
    extends ConsumerState<DoctorAvailabilityScreen> {
  final _reasonController = TextEditingController();
  bool _loading = true;
  bool _savingRules = false;
  bool _savingBlocked = false;
  String? _deletingBlockedId;
  String? _error;
  bool _availabilityFeatureUnavailable = false;
  String? _professionalId;
  DateTime? _blockedStart;
  DateTime? _blockedEnd;
  List<_AvailabilityDayDraft> _dayDrafts = _buildDefaultDrafts();
  List<BlockedPeriodItem> _blockedPeriods = const [];

  static List<_AvailabilityDayDraft> _buildDefaultDrafts() {
    return List.generate(
      7,
      (index) => _AvailabilityDayDraft(
        dayOfWeek: index,
        isActive: false,
        startTime: '09:00:00',
        endTime: '18:00:00',
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('doctor_availability_title')),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_availabilityFeatureUnavailable) ...[
                      GKCard(
                        child: Text(
                          t('doctor_availability_backend_unavailable'),
                          style: const TextStyle(color: GKColors.neutral),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      t('doctor_availability_weekly_title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('doctor_availability_weekly_subtitle'),
                      style: const TextStyle(color: GKColors.neutral),
                    ),
                    const SizedBox(height: 10),
                    GKCard(
                      child: Column(
                        children: [
                          ..._dayDrafts.asMap().entries.map(
                            (entry) {
                              final index = entry.key;
                              final draft = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      index == _dayDrafts.length - 1 ? 0 : 10,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _weekdayLabel(draft.dayOfWeek, t),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: draft.isActive,
                                          onChanged: (value) {
                                            setState(
                                              () => _updateDraft(
                                                draft.dayOfWeek,
                                                draft.copyWith(isActive: value),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    if (draft.isActive)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () async {
                                                final selected =
                                                    await _pickTime(
                                                  draft.startTime,
                                                );
                                                if (selected == null) return;
                                                setState(
                                                  () => _updateDraft(
                                                    draft.dayOfWeek,
                                                    draft.copyWith(
                                                      startTime: selected,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                '${t('doctor_availability_start')} ${_displayTime(draft.startTime)}',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () async {
                                                final selected =
                                                    await _pickTime(
                                                  draft.endTime,
                                                );
                                                if (selected == null) return;
                                                setState(
                                                  () => _updateDraft(
                                                    draft.dayOfWeek,
                                                    draft.copyWith(
                                                      endTime: selected,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                '${t('doctor_availability_end')} ${_displayTime(draft.endTime)}',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _availabilityFeatureUnavailable ||
                                      _savingRules
                                  ? null
                                  : _saveRules,
                              child: Text(
                                _savingRules
                                    ? t('saving')
                                    : t('doctor_availability_save_button'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      t('doctor_availability_blocks_title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('doctor_availability_blocks_subtitle'),
                      style: const TextStyle(color: GKColors.neutral),
                    ),
                    const SizedBox(height: 10),
                    GKCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final dateTime = await _pickDateTime(
                                      initial: _blockedStart ?? DateTime.now(),
                                    );
                                    if (dateTime == null) return;
                                    setState(() => _blockedStart = dateTime);
                                  },
                                  child: Text(
                                    _blockedStart == null
                                        ? t('doctor_availability_start')
                                        : _formatDateTime(_blockedStart!),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final dateTime = await _pickDateTime(
                                      initial: _blockedEnd ??
                                          (_blockedStart ??
                                              DateTime.now().add(
                                                const Duration(hours: 1),
                                              )),
                                    );
                                    if (dateTime == null) return;
                                    setState(() => _blockedEnd = dateTime);
                                  },
                                  child: Text(
                                    _blockedEnd == null
                                        ? t('doctor_availability_end')
                                        : _formatDateTime(_blockedEnd!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reasonController,
                            minLines: 2,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: t('doctor_availability_block_reason'),
                              hintText:
                                  t('doctor_availability_block_reason_hint'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _availabilityFeatureUnavailable ||
                                      _savingBlocked
                                  ? null
                                  : _addBlockedPeriod,
                              child: Text(
                                _savingBlocked
                                    ? t('doctor_availability_adding')
                                    : t('doctor_availability_add_block_button'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_blockedPeriods.isEmpty)
                      GKCard(
                        child: Text(
                          t('doctor_availability_no_blocks'),
                          style: const TextStyle(color: GKColors.neutral),
                        ),
                      )
                    else
                      ..._blockedPeriods.map(
                        (item) => GKCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.reason.trim().isEmpty
                                          ? t('doctor_availability_block_without_reason')
                                          : item.reason.trim(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatNullableDateTime(item.startDateTime)} - ${_formatNullableDateTime(item.endDateTime)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: GKColors.neutral,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _availabilityFeatureUnavailable ||
                                        _deletingBlockedId == item.id
                                    ? null
                                    : () => _deleteBlockedPeriod(item.id),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: GKColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Future<void> _loadData() async {
    final language = ref.read(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    setState(() {
      _loading = true;
      _error = null;
      _availabilityFeatureUnavailable = false;
    });

    try {
      final session = ref.read(authControllerProvider).session;
      final professionalId =
          session?.user.role == 'surgeon' ? session?.user.id : null;
      _professionalId = professionalId;
      final repo = ref.read(appointmentsRepositoryProvider);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final dateTo = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 180)));

      final availability = await repo.getAvailabilityRules(
        professionalId: professionalId,
      );
      final blocked = await repo.getBlockedPeriods(
        professionalId: professionalId,
        dateFrom: today,
        dateTo: dateTo,
      );

      final byDay = <int, ProfessionalAvailabilityRule>{};
      for (final item in availability.rules) {
        byDay.putIfAbsent(item.dayOfWeek, () => item);
      }

      setState(() {
        _dayDrafts = List.generate(
          7,
          (day) {
            final row = byDay[day];
            return _AvailabilityDayDraft(
              dayOfWeek: day,
              isActive: row?.isActive ?? false,
              startTime: row?.startTime ?? '09:00:00',
              endTime: row?.endTime ?? '18:00:00',
            );
          },
        );
        _blockedPeriods = blocked;
        _loading = false;
      });
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 404) {
        setState(() {
          _availabilityFeatureUnavailable = true;
          _dayDrafts = _buildDefaultDrafts();
          _blockedPeriods = const [];
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _error = '${t('doctor_availability_load_error_prefix')}: $error';
        _loading = false;
      });
    }
  }

  void _updateDraft(int dayOfWeek, _AvailabilityDayDraft value) {
    _dayDrafts = _dayDrafts
        .map((draft) => draft.dayOfWeek == dayOfWeek ? value : draft)
        .toList();
  }

  Future<void> _saveRules() async {
    final language = ref.read(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    final active = _dayDrafts.where((item) => item.isActive).toList();
    for (final row in active) {
      if (!_isEndAfterStart(row.startTime, row.endTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${t('doctor_availability_invalid_time_prefix')} ${_weekdayLabel(row.dayOfWeek, t)}: ${t('doctor_availability_invalid_time_suffix')}',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _savingRules = true);
    try {
      final payload = active
          .map(
            (row) => ProfessionalAvailabilityRule(
              id: '',
              dayOfWeek: row.dayOfWeek,
              startTime: row.startTime,
              endTime: row.endTime,
              isActive: true,
            ),
          )
          .toList();
      await ref.read(appointmentsRepositoryProvider).updateAvailabilityRules(
            professionalId: _professionalId,
            rules: payload,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('doctor_availability_save_success')),
        ),
      );
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${t('doctor_availability_save_error_prefix')}: $error',
          ),
        ),
      );
      setState(() => _savingRules = false);
    }
  }

  Future<void> _addBlockedPeriod() async {
    final language = ref.read(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    final start = _blockedStart;
    final end = _blockedEnd;
    final reason = _reasonController.text.trim();
    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('doctor_availability_select_start_end'))),
      );
      return;
    }
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('doctor_availability_end_after_start')),
        ),
      );
      return;
    }
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('doctor_availability_reason_required'))),
      );
      return;
    }

    setState(() => _savingBlocked = true);
    try {
      await ref.read(appointmentsRepositoryProvider).createBlockedPeriod(
            professionalId: _professionalId,
            startDateTime: start.toIso8601String(),
            endDateTime: end.toIso8601String(),
            reason: reason,
          );
      if (!mounted) return;
      _reasonController.clear();
      setState(() {
        _blockedStart = null;
        _blockedEnd = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('doctor_availability_block_added_success'))),
      );
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${t('doctor_availability_add_block_error_prefix')}: $error'),
        ),
      );
      setState(() => _savingBlocked = false);
    }
  }

  Future<void> _deleteBlockedPeriod(String blockedPeriodId) async {
    final language = ref.read(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    setState(() => _deletingBlockedId = blockedPeriodId);
    try {
      await ref.read(appointmentsRepositoryProvider).deleteBlockedPeriod(
            blockedPeriodId: blockedPeriodId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('doctor_availability_block_removed_success'))),
      );
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${t('doctor_availability_remove_block_error_prefix')}: $error',
          ),
        ),
      );
      setState(() => _deletingBlockedId = null);
    }
  }

  Future<String?> _pickTime(String currentValue) async {
    final initial = _parseTime(currentValue);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return null;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  Future<DateTime?> _pickDateTime({required DateTime initial}) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (pickedDate == null) return null;
    if (!mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return null;
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  TimeOfDay _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return const TimeOfDay(hour: 9, minute: 0);
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  String _displayTime(String value) {
    if (value.length < 5) return value;
    return value.substring(0, 5);
  }

  bool _isEndAfterStart(String start, String end) {
    final startParsed = _parseTime(start);
    final endParsed = _parseTime(end);
    final startMinutes = startParsed.hour * 60 + startParsed.minute;
    final endMinutes = endParsed.hour * 60 + endParsed.minute;
    return endMinutes > startMinutes;
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('dd/MM/yyyy HH:mm').format(value);
  }

  String _formatNullableDateTime(DateTime? value) {
    if (value == null) return '-';
    return _formatDateTime(value);
  }

  String _weekdayLabel(
    int dayOfWeek,
    String Function(String key) t,
  ) {
    const keys = <String>[
      'weekday_short_mon',
      'weekday_short_tue',
      'weekday_short_wed',
      'weekday_short_thu',
      'weekday_short_fri',
      'weekday_short_sat',
      'weekday_short_sun',
    ];
    final safeIndex = dayOfWeek.clamp(0, 6);
    return t(keys[safeIndex]);
  }
}

class _AvailabilityDayDraft {
  const _AvailabilityDayDraft({
    required this.dayOfWeek,
    required this.isActive,
    required this.startTime,
    required this.endTime,
  });

  final int dayOfWeek;
  final bool isActive;
  final String startTime;
  final String endTime;

  _AvailabilityDayDraft copyWith({
    bool? isActive,
    String? startTime,
    String? endTime,
  }) {
    return _AvailabilityDayDraft(
      dayOfWeek: dayOfWeek,
      isActive: isActive ?? this.isActive,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
