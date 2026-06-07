import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/export_service.dart';
import '../../core/services/nim_service.dart';
import '../../core/theme/app_theme.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _exporting = false;
  String? _aiSummary;
  bool _generatingSummary = false;

  @override
  Widget build(BuildContext context) {
    final tradesAsync = ref.watch(closedTradesProvider);
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              final scaffoldMsg = ScaffoldMessenger.of(context);
              final trades =
                  await ref.read(tradesRepositoryProvider).getClosedTrades(
                        ref.read(currentUserProvider)?.uid ?? '',
                      );
              if (trades.isEmpty) {
                scaffoldMsg.showSnackBar(
                  const SnackBar(content: Text('No closed trades to export')),
                );
                return;
              }
              setState(() => _exporting = true);
              try {
                if (v == 'csv') {
                  await ExportService.exportTradesToCsv(trades);
                } else {
                  final wins = trades.where((t) => (t.pnl ?? 0) > 0).length;
                  final winRate =
                      trades.isEmpty ? 0.0 : wins / trades.length * 100;
                  final totalPnl = trades.fold<double>(
                      0, (s, t) => s + (t.pnl ?? 0));
                  final totalPips = trades.fold<double>(
                      0, (s, t) => s + (t.pips ?? 0));
                  await ExportService.exportTradesToPdf(
                    trades,
                    winRate: winRate,
                    totalPnl: totalPnl,
                    totalPips: totalPips,
                  );
                }
              } finally {
                if (mounted) setState(() => _exporting = false);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'csv', child: Text('Export CSV')),
              const PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
            ],
            icon: _exporting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: tradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (trades) {
          if (trades.isEmpty) {
            return const Center(
              child: Text(
                'No closed trades yet.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final wins = trades.where((t) => (t.pnl ?? 0) > 0).length;
          final losses = trades.where((t) => (t.pnl ?? 0) < 0).length;
          final winRate = trades.isEmpty
              ? 0.0
              : wins / trades.length * 100;
          final totalPnl =
              trades.fold<double>(0, (s, t) => s + (t.pnl ?? 0));
          final totalPips =
              trades.fold<double>(0, (s, t) => s + (t.pips ?? 0));
          final best = trades.reduce(
              (a, b) => (a.pnl ?? 0) > (b.pnl ?? 0) ? a : b);
          final worst = trades.reduce(
              (a, b) => (a.pnl ?? 0) < (b.pnl ?? 0) ? a : b);

          // Build equity curve data
          double running = 0;
          final equityPoints = <FlSpot>[];
          for (int i = 0; i < trades.length; i++) {
            running += trades[i].pnl ?? 0;
            equityPoints.add(FlSpot(i.toDouble(), running));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Stats grid
              _StatsGrid(children: [
                _StatCard(
                    label: 'Win Rate',
                    value: '${winRate.toStringAsFixed(1)}%',
                    color: winRate >= 50
                        ? AppTheme.primaryGreen
                        : AppTheme.dangerRed),
                _StatCard(
                    label: 'Net P&L',
                    value: '\$${fmt.format(totalPnl)}',
                    color: totalPnl >= 0
                        ? AppTheme.primaryGreen
                        : AppTheme.dangerRed),
                _StatCard(
                    label: 'Total Pips',
                    value: fmt.format(totalPips),
                    color: totalPips >= 0
                        ? AppTheme.primaryGreen
                        : AppTheme.dangerRed),
                _StatCard(
                    label: 'Trades',
                    value: '${wins}W / ${losses}L',
                    color: Colors.white),
              ]),
              const SizedBox(height: 16),

              // Best/Worst
              Row(children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Best Trade',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                          Text(
                            '+\$${fmt.format(best.pnl ?? 0)}',
                            style: const TextStyle(
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          Text('${best.direction.toUpperCase()} ${best.symbol}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Worst Trade',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                          Text(
                            '\$${fmt.format(worst.pnl ?? 0)}',
                            style: const TextStyle(
                                color: AppTheme.dangerRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          Text('${worst.direction.toUpperCase()} ${worst.symbol}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // Equity curve
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Equity Curve',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: equityPoints,
                                isCurved: true,
                                color: totalPnl >= 0
                                    ? AppTheme.primaryGreen
                                    : AppTheme.dangerRed,
                                barWidth: 2,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: (totalPnl >= 0
                                          ? AppTheme.primaryGreen
                                          : AppTheme.dangerRed)
                                        .withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // AI Weekly Summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('AI Summary',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 8),
                      if (_aiSummary != null)
                        Text(_aiSummary!,
                            style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _generatingSummary
                            ? null
                            : () => _generateAiSummary(
                                  wins: wins,
                                  losses: losses,
                                  winRate: winRate,
                                  totalPnl: totalPnl,
                                  totalPips: totalPips,
                                ),
                        icon: _generatingSummary
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(_generatingSummary
                            ? 'Generating…'
                            : 'Generate AI Summary'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generateAiSummary({
    required int wins,
    required int losses,
    required double winRate,
    required double totalPnl,
    required double totalPips,
  }) async {
    setState(() => _generatingSummary = true);
    final nim = ref.read(nimServiceProvider);
    if (nim == null) {
      setState(() => _generatingSummary = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configure NIM API key in Settings first.')),
        );
      }
      return;
    }

    try {
      final settings = ref.read(settingsProvider).valueOrNull;
      final balance = ref.read(confirmedBalanceProvider).valueOrNull ?? 0.0;

      final summary = await nim.complete([
        NimService.buildSystemPrompt(
          accountType: settings?.accountType ?? 'usd',
          balance: balance,
          openTradesJson: 'No open trades',
          marginLevelPct: double.infinity,
        ),
        NimMessage(
          role: 'user',
          content:
              'Write a brief performance summary for my trading history: '
              '$wins wins, $losses losses, win rate ${winRate.toStringAsFixed(1)}%, '
              'net P&L \$${totalPnl.toStringAsFixed(2)}, total pips ${totalPips.toStringAsFixed(1)}. '
              'Keep it under 100 words and end with one actionable suggestion.',
        ),
      ]);
      setState(() {
        _aiSummary = summary;
        _generatingSummary = false;
      });
    } catch (e) {
      setState(() => _generatingSummary = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Error: $e')),
        );
      }
    }
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: children,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
