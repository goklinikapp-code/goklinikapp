import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';

class AppointmentStep1SpecialtyScreen extends StatefulWidget {
  const AppointmentStep1SpecialtyScreen({super.key});

  @override
  State<AppointmentStep1SpecialtyScreen> createState() =>
      _AppointmentStep1SpecialtyScreenState();
}

class _AppointmentStep1SpecialtyScreenState
    extends State<AppointmentStep1SpecialtyScreen> {
  String? _selectedId;

  static const _specialties = [
    _SpecialtyItem(
        id: 'rinoplastia',
        name: 'Rinoplastia',
        description: 'Correção estética e funcional do nariz.',
        icon: Icons.face_retouching_natural),
    _SpecialtyItem(
        id: 'mamoplastia',
        name: 'Mamoplastia',
        description: 'Procedimentos mamários personalizados.',
        icon: Icons.favorite_outline),
    _SpecialtyItem(
        id: 'lipoaspiracao',
        name: 'Lipoaspiração',
        description: 'Remodelagem corporal com segurança.',
        icon: Icons.spa_outlined),
    _SpecialtyItem(
        id: 'harmonizacao',
        name: 'Harmonização Facial',
        description: 'Realce de traços e simetria facial.',
        icon: Icons.auto_fix_high),
    _SpecialtyItem(
        id: 'botox',
        name: 'Botox',
        description: 'Suavização de linhas de expressão.',
        icon: Icons.healing),
    _SpecialtyItem(
        id: 'peeling',
        name: 'Peeling',
        description: 'Renovação da pele com protocolo médico.',
        icon: Icons.auto_awesome),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _specialties.firstWhere(
      (item) => item.id == _selectedId,
      orElse: () => _specialties.first,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Novo Agendamento')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'PASSO 01',
                  style: TextStyle(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Escolha a sua especialidade',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text(
                    'Selecione o tratamento para encontrarmos o melhor horário para você.'),
                const SizedBox(height: 16),
                GridView.builder(
                  itemCount: _specialties.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.95,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final specialty = _specialties[index];
                    final selected = specialty.id == _selectedId;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedId = specialty.id),
                      child: GKCard(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: selected
                                ? colorScheme.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? colorScheme.primary
                                  : Colors.transparent,
                              width: 1.6,
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(specialty.icon,
                                    color: colorScheme.primary, size: 20),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                specialty.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Text(
                                  specialty.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
                onPressed: _selectedId == null
                    ? null
                    : () {
                        context.push(
                          '/appointments/new/step2?specialty_id=${selected.id}&specialty_name=${Uri.encodeComponent(selected.name)}',
                        );
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecialtyItem {
  const _SpecialtyItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
}
