import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../data/travel_plans_repository_impl.dart';
import '../domain/travel_plan_models.dart';
import 'travel_plan_controller.dart';

class TravelPlanScreen extends ConsumerStatefulWidget {
  const TravelPlanScreen({super.key});

  @override
  ConsumerState<TravelPlanScreen> createState() => _TravelPlanScreenState();
}

class _TravelPlanScreenState extends ConsumerState<TravelPlanScreen> {
  final Set<String> _confirmingTransfers = <String>{};

  Future<void> _refresh() async {
    ref.invalidate(travelPlanProvider);
    await ref.read(travelPlanProvider.future);
  }

  Future<void> _confirmTransfer(TransferItem transfer) async {
    if (_confirmingTransfers.contains(transfer.id)) return;

    setState(() {
      _confirmingTransfers.add(transfer.id);
    });

    try {
      await ref.read(travelPlansRepositoryProvider).confirmTransfer(transfer.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer confirmado com sucesso.')),
      );
      ref.invalidate(travelPlanProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel confirmar este transfer.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _confirmingTransfers.remove(transfer.id);
        });
      }
    }
  }

  Future<void> _openMapLink(String url) async {
    final link = url.trim();
    if (link.isEmpty) return;

    final uri = Uri.tryParse(link);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planState = ref.watch(travelPlanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano de Viagem'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: planState.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              GKLoadingShimmer(height: 88),
              SizedBox(height: 12),
              GKLoadingShimmer(height: 120),
              SizedBox(height: 12),
              GKLoadingShimmer(height: 120),
            ],
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GKCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nao foi possivel carregar seu plano de viagem.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 14),
                    GKButton(
                      label: 'Tentar novamente',
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
            ],
          ),
          data: (plan) {
            if (plan == null) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GKCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.luggage_rounded, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Plano de Viagem',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'A clinica ainda nao cadastrou seu plano de viagem. '
                          'Assim que estiver pronto, voce vera voos, hotel e transfers aqui.',
                        ),
                        const SizedBox(height: 16),
                        GKButton(
                          label: 'Falar com a clinica',
                          onPressed: () => context.go('/chat'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final subtitle = _buildTravelRangeSubtitle(plan);
            final events = _buildTimelineEvents(plan);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GKCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Plano de Viagem',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(events.length, (index) {
                  final event = events[index];
                  final isLast = index == events.length - 1;
                  return _TimelineTile(
                    event: event,
                    isLast: isLast,
                    isConfirming: _confirmingTransfers.contains(event.transfer?.id),
                    onConfirmTransfer: event.transfer == null
                        ? null
                        : () => _confirmTransfer(event.transfer!),
                    onOpenMap:
                        event.mapLink == null ? null : () => _openMapLink(event.mapLink!),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.event,
    required this.isLast,
    required this.isConfirming,
    this.onConfirmTransfer,
    this.onOpenMap,
  });

  final _TimelineEvent event;
  final bool isLast;
  final bool isConfirming;
  final VoidCallback? onConfirmTransfer;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final timelineColor = Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: timelineColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(event.icon, size: 18, color: timelineColor),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 86,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: timelineColor.withValues(alpha: 0.22),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: GKCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy - HH:mm', 'pt_BR').format(event.dateTime),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (event.routeText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(event.routeText),
                  ],
                  if (event.observations.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.observations,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                  if (event.status != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        GKBadge(
                          label: _statusLabel(event.status!),
                          background: _statusBackground(event.status!),
                          foreground: _statusForeground(event.status!),
                        ),
                        if (event.confirmedByPatient)
                          const GKBadge(
                            label: 'VISTO PELO PACIENTE',
                            background: Color(0xFFD1FAE5),
                            foreground: Color(0xFF047857),
                          ),
                      ],
                    ),
                  ],
                  if (onOpenMap != null) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: onOpenMap,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Abrir no Google Maps'),
                    ),
                  ],
                  if (event.transfer?.canConfirmRead == true && onConfirmTransfer != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isConfirming ? null : onConfirmTransfer,
                        icon: isConfirming
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          isConfirming ? 'Confirmando...' : 'Confirmar que viu',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GKColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineEvent {
  const _TimelineEvent({
    required this.id,
    required this.icon,
    required this.title,
    required this.dateTime,
    required this.routeText,
    required this.observations,
    required this.status,
    required this.confirmedByPatient,
    required this.mapLink,
    required this.transfer,
  });

  final String id;
  final IconData icon;
  final String title;
  final DateTime dateTime;
  final String routeText;
  final String observations;
  final String? status;
  final bool confirmedByPatient;
  final String? mapLink;
  final TransferItem? transfer;
}

List<_TimelineEvent> _buildTimelineEvents(TravelPlanModel plan) {
  final events = <_TimelineEvent>[];

  if (plan.arrivalFlight != null) {
    final flight = plan.arrivalFlight!;
    events.add(
      _TimelineEvent(
        id: 'arrival-${flight.id}',
        icon: Icons.flight_takeoff_rounded,
        title: 'Voo de Chegada ${flight.flightNumber}'.trim(),
        dateTime: flight.dateTime,
        routeText: flight.airport,
        observations: flight.observations,
        status: null,
        confirmedByPatient: false,
        mapLink: _buildMapSearchLink(flight.airport),
        transfer: null,
      ),
    );
  }

  if (plan.hotel != null) {
    final hotel = plan.hotel!;
    final mapLink = hotel.locationLink.trim().isNotEmpty
        ? hotel.locationLink.trim()
        : _buildMapSearchLink(hotel.address);

    events.add(
      _TimelineEvent(
        id: 'hotel-checkin-${hotel.id}',
        icon: Icons.bed_rounded,
        title: 'Check-in no Hotel ${hotel.hotelName}'.trim(),
        dateTime: hotel.checkinDateTime,
        routeText: hotel.address,
        observations: hotel.observations,
        status: null,
        confirmedByPatient: false,
        mapLink: mapLink,
        transfer: null,
      ),
    );
  }

  for (final transfer in plan.transfers) {
    String? mapLink;
    if (_containsHotelOrClinic(transfer.origin) ||
        _containsHotelOrClinic(transfer.destination)) {
      final query =
          transfer.destination.trim().isNotEmpty ? transfer.destination : transfer.origin;
      mapLink = _buildMapSearchLink(query);
    }

    events.add(
      _TimelineEvent(
        id: 'transfer-${transfer.id}',
        icon: Icons.directions_car_filled_rounded,
        title: transfer.title,
        dateTime: transfer.dateTime,
        routeText: '${transfer.origin} -> ${transfer.destination}',
        observations: transfer.observations,
        status: transfer.status,
        confirmedByPatient: transfer.confirmedByPatient,
        mapLink: mapLink,
        transfer: transfer,
      ),
    );
  }

  if (plan.departureFlight != null) {
    final flight = plan.departureFlight!;
    events.add(
      _TimelineEvent(
        id: 'departure-${flight.id}',
        icon: Icons.flight_land_rounded,
        title: 'Voo de Regresso ${flight.flightNumber}'.trim(),
        dateTime: flight.dateTime,
        routeText: flight.airport,
        observations: flight.observations,
        status: null,
        confirmedByPatient: false,
        mapLink: _buildMapSearchLink(flight.airport),
        transfer: null,
      ),
    );
  }

  events.sort((a, b) {
    final byDate = a.dateTime.compareTo(b.dateTime);
    if (byDate != 0) return byDate;
    return a.id.compareTo(b.id);
  });

  return events;
}

String _buildTravelRangeSubtitle(TravelPlanModel plan) {
  final start = plan.tripStartDate;
  final end = plan.tripEndDate;
  if (start == null && end == null) {
    return 'A clinica esta organizando seus detalhes de viagem.';
  }

  final formatter = DateFormat('dd MMM yyyy', 'pt_BR');
  if (start != null && end != null) {
    return '${formatter.format(start)} a ${formatter.format(end)}';
  }
  if (start != null) {
    return 'Inicio previsto em ${formatter.format(start)}';
  }
  return 'Termino previsto em ${formatter.format(end!)}';
}

String _statusLabel(String status) {
  switch (status) {
    case 'scheduled':
      return 'Agendado';
    case 'confirmed':
      return 'Confirmado';
    case 'completed':
      return 'Concluido';
    case 'cancelled':
      return 'Cancelado';
    default:
      return status;
  }
}

Color _statusBackground(String status) {
  switch (status) {
    case 'scheduled':
      return const Color(0xFFFEF3C7);
    case 'confirmed':
      return const Color(0xFFCCFBF1);
    case 'completed':
      return const Color(0xFFDCFCE7);
    case 'cancelled':
      return const Color(0xFFE2E8F0);
    default:
      return const Color(0xFFE2E8F0);
  }
}

Color _statusForeground(String status) {
  switch (status) {
    case 'scheduled':
      return const Color(0xFF92400E);
    case 'confirmed':
      return const Color(0xFF0F766E);
    case 'completed':
      return const Color(0xFF166534);
    case 'cancelled':
      return const Color(0xFF475569);
    default:
      return const Color(0xFF334155);
  }
}

bool _containsHotelOrClinic(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('hotel') ||
      normalized.contains('clinic') ||
      normalized.contains('clinica') ||
      normalized.contains('clinica');
}

String _buildMapSearchLink(String query) {
  final value = query.trim();
  if (value.isEmpty) return '';
  return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(value)}';
}
