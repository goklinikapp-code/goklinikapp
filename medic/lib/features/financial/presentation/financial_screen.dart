import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final state = ref.watch(financialProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Financeiro')),
      body: state.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            GKLoadingShimmer(height: 120),
            SizedBox(height: 10),
            GKLoadingShimmer(height: 200),
          ],
        ),
        error: (error, _) => Center(child: Text('Erro ao carregar financeiro: $error')),
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
    final due = summary.nextDue;

    return DefaultTabController(
      length: 2,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Seu resumo mensal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          GKCard(
            color: GKColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PRÓXIMA FATURA', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  due == null ? 'Sem cobrança pendente' : formatCurrency(due.amount),
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  due?.dueDate == null ? '-' : 'Vencimento: ${formatDate(due!.dueDate!)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GKCard(
            child: Row(
              children: [
                const Expanded(child: Text('SALDO EM ABERTO', style: TextStyle(fontWeight: FontWeight.w700))),
                Text(formatCurrency(summary.openBalance), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const GKBadge(label: 'parcelado', background: Color(0xFFFFF1CF), foreground: GKColors.accent),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const TabBar(
            tabs: [
              Tab(text: 'Histórico'),
              Tab(text: 'Pacotes'),
            ],
          ),
          SizedBox(
            height: 440,
            child: TabBarView(
              children: [
                _TransactionsTab(items: summary.transactions),
                _PackagesTab(items: summary.packages),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GKButton(
                  label: 'Copiar IBAN',
                  variant: GKButtonVariant.secondary,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('IBAN copiado para área de transferência.')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GKButton(
                  label: 'Fatura PDF',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Download da fatura será disponibilizado em breve.')),
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
  const _TransactionsTab({required this.items});

  final List<TransactionItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Nenhuma transação encontrada.'));
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
          title: Text(item.description.isEmpty ? 'Transação' : item.description),
          subtitle: Text(item.dueDate == null ? '-' : formatDate(item.dueDate!)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCurrency(item.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              GKBadge(
                label: isPaid ? 'PAGO' : 'PENDENTE',
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
  const _PackagesTab({required this.items});

  final List<SessionPackageItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Sem pacotes de sessões ativos.'));
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
              Text(item.packageName, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${item.sessionsRemaining} sessões restantes de ${item.totalSessions}'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                color: GKColors.primary,
                backgroundColor: const Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 8),
              Text('Total: ${formatCurrency(item.totalAmount)}'),
            ],
          ),
        );
      },
    );
  }
}
