import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../domain/referral_models.dart';
import 'referrals_controller.dart';

class ReferralsScreen extends ConsumerWidget {
  const ReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralsState = ref.watch(referralsProvider);
    final language = ref.watch(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('referrals_title')),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(referralsProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: referralsState.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            GKLoadingShimmer(height: 120),
            SizedBox(height: 12),
            GKLoadingShimmer(height: 220),
          ],
        ),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (summary) => _ReferralsContent(summary: summary, t: t),
      ),
    );
  }
}

class _ReferralsContent extends StatelessWidget {
  const _ReferralsContent({required this.summary, required this.t});

  final ReferralSummary summary;
  final String Function(String key) t;

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: summary.referralLink));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t('referrals_link_copied'))));
  }

  Future<void> _shareWhatsApp(BuildContext context) async {
    final message =
        t('referrals_message').replaceAll('{link}', summary.referralLink);
    final encoded = Uri.encodeComponent(message);
    final whatsappUri = Uri.parse('whatsapp://send?text=$encoded');
    final fallbackUri = Uri.parse('https://wa.me/?text=$encoded');

    final opened =
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareEmail(BuildContext context) async {
    final subject = Uri.encodeComponent(t('referrals_email_subject'));
    final body = Uri.encodeComponent(
        t('referrals_message').replaceAll('{link}', summary.referralLink));
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t('referrals_title'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(t('referrals_subtitle'),
            style: const TextStyle(color: GKColors.neutral)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.secondary,
                colorScheme.secondary.withValues(alpha: 0.82),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('referrals_summary_paid_amount'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatCurrency(summary.totalCommissionPaid),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${t('referrals_summary_pending_balance')}: ${formatCurrency(summary.totalCommissionPending)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GKColors.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('referrals_share_link'),
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SelectableText(
                summary.referralLink,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _copyLink(context),
                icon: const Icon(Icons.copy, color: Colors.white),
                label: Text(t('referrals_copy_link'),
                    style: const TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ShareButton(
              icon: Icons.chat,
              label: t('referrals_share_whatsapp'),
              onTap: () => _shareWhatsApp(context),
            ),
            _ShareButton(
              icon: Icons.copy,
              label: t('referrals_share_copy'),
              onTap: () => _copyLink(context),
            ),
            _ShareButton(
              icon: Icons.email_outlined,
              label: t('referrals_share_email'),
              onTap: () => _shareEmail(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: t('referrals_summary_total'),
                value: summary.totalReferrals.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: t('referrals_summary_converted'),
                value: summary.totalConverted.toString(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: t('referrals_summary_paid'),
                value: summary.totalPaid.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(t('referrals_history_title'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (summary.items.isEmpty)
          GKCard(child: Text(t('referrals_empty')))
        else
          ...summary.items
              .map((item) => _ReferralHistoryItem(item: item, t: t)),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: (MediaQuery.of(context).size.width - 52) / 3,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: GKColors.primary),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GKCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: GKColors.neutral)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ReferralHistoryItem extends StatelessWidget {
  const _ReferralHistoryItem({
    required this.item,
    required this.t,
  });

  final ReferralItem item;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    final statusVisual = switch (item.status) {
      'paid' => (
          label: t('referrals_status_paid'),
          background: GKColors.tealIce,
          foreground: GKColors.primary,
        ),
      'converted' => (
          label: t('referrals_status_converted'),
          background: const Color(0xFFDDF5E3),
          foreground: GKColors.secondary,
        ),
      _ => (
          label: t('referrals_status_pending'),
          background: const Color(0xFFFFF1CF),
          foreground: GKColors.accent,
        ),
    };

    return GKCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: GKColors.tealIce,
            child: Text(
              (item.referredName.isNotEmpty ? item.referredName : '?')
                  .substring(0, 1)
                  .toUpperCase(),
              style: const TextStyle(
                  color: GKColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.referredName.isEmpty
                      ? t('patient_default')
                      : item.referredName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(item.referredEmail,
                    style:
                        const TextStyle(fontSize: 12, color: GKColors.neutral)),
                const SizedBox(height: 4),
                Text(
                  '${t('referrals_date_label')}: ${item.createdAt == null ? '-' : formatDate(item.createdAt!)}',
                  style: const TextStyle(fontSize: 12, color: GKColors.neutral),
                ),
                if (item.commissionValue > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${t('referrals_commission_label')}: ${formatCurrency(item.commissionValue)}',
                    style:
                        const TextStyle(fontSize: 12, color: GKColors.neutral),
                  ),
                ],
              ],
            ),
          ),
          GKBadge(
            label: statusVisual.label,
            background: statusVisual.background,
            foreground: statusVisual.foreground,
          ),
        ],
      ),
    );
  }
}
