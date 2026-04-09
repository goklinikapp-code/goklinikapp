import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../domain/financial_models.dart';
import 'financial_controller.dart';

class FinancialScreen extends ConsumerWidget {
  const FinancialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => _t(context, key);
    final state = ref.watch(financialProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('financial_title'))),
      body: state.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            GKLoadingShimmer(height: 120),
            SizedBox(height: 10),
            GKLoadingShimmer(height: 200),
          ],
        ),
        error: (error, _) => Center(
          child: Text('${t('financial_load_error_prefix')}: $error'),
        ),
        data: (summary) => _FinancialContent(summary: summary),
      ),
    );
  }
}

class _FinancialContent extends StatelessWidget {
  const _FinancialContent({required this.summary});

  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    String t(String key) => _t(context, key);
    final due = summary.nextDue;

    return DefaultTabController(
      length: 2,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            t('financial_monthly_summary'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          GKCard(
            color: GKColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('financial_next_invoice'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  due == null
                      ? t('financial_no_pending_charge')
                      : formatCurrency(due.amount),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  due?.dueDate == null
                      ? '-'
                      : t('financial_due_date')
                          .replaceAll('{date}', formatDate(due!.dueDate!)),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GKCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t('financial_open_balance'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(formatCurrency(summary.openBalance),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                GKBadge(
                  label: t('financial_installments_badge'),
                  background: const Color(0xFFFFF1CF),
                  foreground: GKColors.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TabBar(
            tabs: [
              Tab(text: t('medical_record_tab_history')),
              Tab(text: t('financial_packages_tab')),
            ],
          ),
          SizedBox(
            height: 440,
            child: TabBarView(
              children: [
                _TransactionsTab(items: summary.transactions, t: t),
                _PackagesTab(items: summary.packages, t: t),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GKButton(
                  label: t('financial_copy_iban'),
                  variant: GKButtonVariant.secondary,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('financial_iban_copied')),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GKButton(
                  label: t('financial_invoice_pdf'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('financial_invoice_download_soon')),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({
    required this.items,
    required this.t,
  });

  final List<TransactionItem> items;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(t('financial_no_transactions')));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isPaid = item.status == 'paid';

        return ListTile(
          leading: Icon(
            isPaid ? Icons.check_circle_outline : Icons.pending_actions,
            color: isPaid ? GKColors.secondary : GKColors.accent,
          ),
          title: Text(
            item.description.isEmpty
                ? t('financial_transaction_default')
                : item.description,
          ),
          subtitle:
              Text(item.dueDate == null ? '-' : formatDate(item.dueDate!)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCurrency(item.amount),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              GKBadge(
                label: isPaid
                    ? t('financial_status_paid')
                    : t('financial_status_pending'),
                background: isPaid ? GKColors.secondary : GKColors.accent,
                foreground: Colors.white,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PackagesTab extends StatelessWidget {
  const _PackagesTab({
    required this.items,
    required this.t,
  });

  final List<SessionPackageItem> items;
  final String Function(String key) t;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(t('financial_no_active_packages')));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final progress = item.totalSessions == 0
            ? 0.0
            : (item.usedSessions / item.totalSessions).clamp(0, 1).toDouble();

        return GKCard(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.packageName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                t('financial_sessions_remaining')
                    .replaceAll('{remaining}', '${item.sessionsRemaining}')
                    .replaceAll('{total}', '${item.totalSessions}'),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                color: GKColors.primary,
                backgroundColor: const Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 8),
              Text(
                t('financial_total')
                    .replaceAll('{amount}', formatCurrency(item.totalAmount)),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _t(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  return appTr(key: key, language: language);
}
