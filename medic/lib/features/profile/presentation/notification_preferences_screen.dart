import 'package:flutter/material.dart';

import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool reminder = true;
  bool postop = true;
  bool offers = false;
  bool newsletter = false;

  @override
  Widget build(BuildContext context) {
    String t(String key) => _t(context, key);
    return Scaffold(
      appBar: AppBar(title: Text(t('notification_preferences'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t('notification_pref_heading'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(t('notification_pref_subheading')),
          const SizedBox(height: 12),
          GKCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('notification_pref_consultation_reminders')),
                  subtitle: Text(t('notification_pref_consultation_desc')),
                  value: reminder,
                  onChanged: (v) => setState(() => reminder = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('notification_pref_postop_followup')),
                  subtitle: Text(t('notification_pref_postop_desc')),
                  value: postop,
                  onChanged: (v) => setState(() => postop = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Text(t('news_offers')),
                      const SizedBox(width: 6),
                      GKBadge(
                        label: t('vip_badge'),
                        background: const Color(0xFFFFF1CF),
                        foreground: GKColors.accent,
                      ),
                    ],
                  ),
                  value: offers,
                  onChanged: (v) => setState(() => offers = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('notification_pref_clinic_newsletters')),
                  value: newsletter,
                  onChanged: (v) => setState(() => newsletter = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GKCard(
            color: GKColors.primary,
            child: Text(
              t('notification_pref_privacy_note'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

String _t(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  return appTr(key: key, language: language);
}
