import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import 'postop_controller.dart';

class CareCenterScreen extends ConsumerWidget {
  const CareCenterScreen({super.key, required this.journeyId});

  final String journeyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(careCenterProvider(journeyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Central de Cuidados')),
      body: state.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => const GKLoadingShimmer(height: 92),
        ),
        error: (error, _) => Center(child: Text('Erro ao carregar cuidados: $error')),
        data: (data) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Central de Cuidados', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('Conteúdo personalizado para sua recuperação pós-operatória.'),
              const SizedBox(height: 12),
              GKCard(
                color: const Color(0xFFE9F7ED),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_hospital_rounded, color: GKColors.secondary),
                        SizedBox(width: 10),
                        Expanded(child: Text('DISPONÍVEL AGORA • Falar com Enfermagem')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GKButton(
                      label: 'Iniciar conversa',
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GKCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dúvidas frequentes', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...data.faqs.map(
                      (faq) => ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(faq['question'] ?? ''),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(faq['answer'] ?? ''),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GKCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Medicamentos', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...data.medications.map(
                      (med) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.medication_outlined, color: GKColors.primary),
                        title: Text(med['name'] ?? ''),
                        subtitle: Text('${med['dosage'] ?? ''} • ${med['schedule'] ?? ''}'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GKCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Orientações gerais', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...data.guidanceLinks.map(
                      (link) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.open_in_new, color: GKColors.primary),
                        title: Text(link),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: GKColors.tealIce,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Estamos aqui 24h por dia para acompanhar sua recuperação.'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
