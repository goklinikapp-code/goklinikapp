import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  bool reminder = true;
  bool postop = true;
  bool offers = false;
  bool newsletter = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferências de Notificação')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Sua Central de Paz', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('Configure o que você deseja receber para manter sua rotina tranquila.'),
          const SizedBox(height: 12),
          GKCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lembretes de consulta'),
                  subtitle: const Text('Avisos de horário e confirmação de presença.'),
                  value: reminder,
                  onChanged: (v) => setState(() => reminder = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Acompanhamento pós-operatório'),
                  subtitle: const Text('Checklist diário e alertas da recuperação.'),
                  value: postop,
                  onChanged: (v) => setState(() => postop = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Row(
                    children: [
                      Text('Promoções e ofertas'),
                      SizedBox(width: 6),
                      GKBadge(label: 'VIP', background: Color(0xFFFFF1CF), foreground: GKColors.accent),
                    ],
                  ),
                  value: offers,
                  onChanged: (v) => setState(() => offers = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Newsletters da clínica'),
                  value: newsletter,
                  onChanged: (v) => setState(() => newsletter = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const GKCard(
            color: GKColors.primary,
            child: Text(
              'Sua privacidade é prioridade. Todas as preferências e dados são protegidos por criptografia.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
