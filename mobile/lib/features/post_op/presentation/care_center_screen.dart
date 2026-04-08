import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
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
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    return Scaffold(
      appBar: AppBar(title: Text(t('postop_care_center_title'))),
      body: state.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => const GKLoadingShimmer(height: 92),
        ),
        error: (error, _) => Center(
          child: Text('${t('postop_care_center_load_error_prefix')} $error'),
        ),
        data: (data) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                t('postop_care_center_title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(t('postop_care_center_subtitle')),
              const SizedBox(height: 12),
              GKCard(
                color: const Color(0xFFE9F7ED),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_hospital_rounded,
                            color: GKColors.secondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t('postop_care_center_available_now_nursing'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GKButton(
                      label: t('postop_care_center_start_chat'),
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
                    Text(
                      t('postop_care_center_faq'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
                    Text(
                      t('postop_care_center_medications'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...data.medications.map(
                      (med) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.medication_outlined,
                            color: GKColors.primary),
                        title: Text(med['name'] ?? ''),
                        subtitle: Text(
                            '${med['dosage'] ?? ''} • ${med['schedule'] ?? ''}'),
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
                    Text(
                      t('postop_care_center_general_guidance'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...data.guidanceLinks.map(
                      (link) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.open_in_new,
                            color: GKColors.primary),
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
                      child: Text(t('postop_care_center_support_24h')),
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
