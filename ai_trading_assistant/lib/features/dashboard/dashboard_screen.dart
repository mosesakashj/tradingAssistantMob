import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/stopout_calculator.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/margin_gauge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(openTradesProvider);
    final closedAsync = ref.watch(closedTradesProvider);
    final balanceAsync = ref.watch(confirmedBalanceProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final calculator = ref.watch(stopoutCalculatorProvider);
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Risk Calculator',
            onPressed: () => context.push('/calculator'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: tradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (trades) {
          final balance =
              balanceAsync.valueOrNull ?? 0.0;
          final settings = settingsAsync.valueOrNull;

          // Build trade summaries
          final summaries = trades
              .map((t) => TradeSummary(
                    pair: t.symbol,
                    lots: t.lots,
                    entryPrice: t.entryPrice,
                  ))
              .toList();

          final marginLevel = calculator?.marginLevelPct(
                equity: balance,
                openTrades: summaries,
              ) ??
              double.infinity;

          // Dynamic per-symbol data
          final symbols =
              trades.map((t) => t.symbol).toSet().toList()..sort();

          // Recent performance (last 30 days)
          final recentClosed = (closedAsync.valueOrNull ?? [])
              .where((t) =>
                  t.closedAt != null &&
                  t.closedAt!.isAfter(
                      DateTime.now().subtract(const Duration(days: 30))))
              .toList();
          final wins =
              recentClosed.where((t) => (t.pnl ?? 0) > 0).length;
          final recentPnl = recentClosed.fold<double>(
              0, (s, t) => s + (t.pnl ?? 0));
          final winRate = recentClosed.isEmpty
              ? 0.0
              : wins / recentClosed.length * 100;

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balance row
                _InfoRow(
                  children: [
                    _InfoCard(
                        label: 'Balance',
                        value: '\$${fmt.format(balance)}',
                        color: AppTheme.primaryGreen),
                    _InfoCard(
                        label: 'Open Trades',
                        value: trades.length.toString(),
                        color: Colors.white),
                  ],
                ),
                const SizedBox(height: 16),

                // Margin gauge
                if (trades.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Margin Level',
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          MarginGauge(marginLevelPct: marginLevel),
                          const SizedBox(height: 8),
                          Text(
                            marginLevel == double.infinity
                                ? '∞'
                                : '${marginLevel.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color:
                                  AppTheme.marginLevelColor(marginLevel),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dynamic per-symbol stopout cards
                  if (symbols.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: symbols.map((sym) {
                        final symLots = trades
                            .where((t) => t.symbol == sym)
                            .fold<double>(0, (s, t) => s + t.lots);
                        final stopPrice =
                            calculator?.stopoutPriceForPair(
                                  pair: sym,
                                  equity: balance,
                                  openTrades: summaries,
                                ) ??
                                0.0;
                        return SizedBox(
                          width:
                              (MediaQuery.of(context).size.width - 48) /
                              2,
                          child: _InfoCard(
                            label: '$sym Stopout',
                            value: '\$${fmt.format(stopPrice)}',
                            sublabel:
                                '${symLots.toStringAsFixed(2)} lots',
                            color: AppTheme.dangerRed,
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),

                  // Recent performance card
                  if (recentClosed.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Last 30 Days',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCell(
                                      'Trades',
                                      recentClosed.length.toString()),
                                ),
                                Expanded(
                                  child: _StatCell('Win Rate',
                                      '${winRate.toStringAsFixed(1)}%'),
                                ),
                                Expanded(
                                  child: _StatCell(
                                    '30d P&L',
                                    '${recentPnl >= 0 ? '+' : ''}\$${fmt.format(recentPnl)}',
                                    valueColor: recentPnl >= 0
                                        ? AppTheme.primaryGreen
                                        : AppTheme.dangerRed,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Margin call warning banner
                  if (settings != null &&
                      marginLevel != double.infinity &&
                      marginLevel < settings.marginCallPct)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.warningYellow.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              color: AppTheme.warningYellow),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Margin level below warning threshold '
                              '(${settings.marginCallPct.toStringAsFixed(0)}%). '
                              'Consider reducing exposure.',
                              style: const TextStyle(
                                  color: AppTheme.warningYellow,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                ] else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No open positions.\nTap + to open a trade.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .map((c) => Expanded(
                child:
                    Padding(padding: const EdgeInsets.only(right: 8), child: c),
              ))
          .toList(),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    required this.color,
    this.sublabel,
  });

  final String label;
  final String value;
  final Color color;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color)),
            if (sublabel != null)
              Text(sublabel!,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }
}
