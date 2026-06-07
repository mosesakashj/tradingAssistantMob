import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/stopout_calculator.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/margin_gauge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(openTradesProvider);
    final balanceAsync = ref.watch(confirmedBalanceProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final calculator = ref.watch(stopoutCalculatorProvider);
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
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

          final xauStopout = calculator?.stopoutPriceForPair(
                pair: 'XAUUSD',
                equity: balance,
                openTrades: summaries,
              ) ??
              0.0;
          final xagStopout = calculator?.stopoutPriceForPair(
                pair: 'XAGUSD',
                equity: balance,
                openTrades: summaries,
              ) ??
              0.0;

          // Aggregate lots and floating P&L across open trades
          final xauTrades = trades.where((t) => t.symbol == 'XAUUSD');
          final xagTrades = trades.where((t) => t.symbol == 'XAGUSD');
          final xauLots =
              xauTrades.fold<double>(0, (s, t) => s + t.lots);
          final xagLots =
              xagTrades.fold<double>(0, (s, t) => s + t.lots);

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

                  // Stopout levels side by side
                  _InfoRow(
                    children: [
                      _InfoCard(
                        label: 'XAUUSD Stopout',
                        value: xauTrades.isEmpty
                            ? '—'
                            : '\$${fmt.format(xauStopout)}',
                        sublabel: xauLots > 0
                            ? '${xauLots.toStringAsFixed(2)} lots'
                            : null,
                        color: AppTheme.dangerRed,
                      ),
                      _InfoCard(
                        label: 'XAGUSD Stopout',
                        value: xagTrades.isEmpty
                            ? '—'
                            : '\$${fmt.format(xagStopout)}',
                        sublabel: xagLots > 0
                            ? '${xagLots.toStringAsFixed(2)} lots'
                            : null,
                        color: AppTheme.dangerRed,
                      ),
                    ],
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
