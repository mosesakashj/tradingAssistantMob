import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/trading_constants.dart';
import '../../core/models/trade_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/export_service.dart';
import '../../core/services/nim_service.dart';
import '../../core/theme/app_theme.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _exporting = false;
  String? _aiSummary;
  bool _generatingSummary = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tradesAsync = ref.watch(closedTradesProvider);
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryGreen,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'By Market'),
            Tab(text: 'By Symbol'),
            Tab(text: 'By Session'),
            Tab(text: 'By Setup'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              final scaffoldMsg = ScaffoldMessenger.of(context);
              final uid = ref.read(currentUserProvider)?.uid ?? '';
              final trades = await ref
                  .read(tradesRepositoryProvider)
                  .getClosedTrades(uid);
              if (trades.isEmpty) {
                scaffoldMsg.showSnackBar(
                  const SnackBar(
                      content: Text('No closed trades to export')),
                );
                return;
              }
              setState(() => _exporting = true);
              try {
                if (v == 'csv') {
                  await ExportService.exportTradesToCsv(trades);
                } else {
                  final s = AnalyticsService.compute(trades);
                  await ExportService.exportTradesToPdf(
                    trades,
                    winRate: s.winRate,
                    totalPnl: s.netPnl,
                    totalPips: s.totalPips,
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
        data: (allTrades) {
          if (allTrades.isEmpty) {
            return const Center(
              child: Text('No closed trades yet.',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          // Sort chronologically for equity curve
          final trades = [...allTrades]
            ..sort((a, b) =>
                (a.closedAt ?? a.openedAt)
                    .compareTo(b.closedAt ?? b.openedAt));

          final stats = AnalyticsService.compute(trades);
          final byMarket =
              AnalyticsService.groupBy(trades, (t) => t.market);
          final bySymbol =
              AnalyticsService.groupBy(trades, (t) => t.symbol);
          final bySession =
              AnalyticsService.groupBy(trades, (t) => t.session);
          final bySetup =
              AnalyticsService.groupBy(trades, (t) => t.setup);

          return TabBarView(
            controller: _tabs,
            children: [
              _OverviewTab(
                trades: trades,
                stats: stats,
                aiSummary: _aiSummary,
                generatingSummary: _generatingSummary,
                onGenerateSummary: () => _generateAiSummary(stats),
                fmt: fmt,
              ),
              _BreakdownTab(
                grouped: byMarket,
                labelMap: const {
                  'forex': 'Forex',
                  'metals': 'Metals',
                  'crypto': 'Crypto',
                  'indices': 'Indices',
                },
              ),
              _BreakdownTab(grouped: bySymbol),
              _BreakdownTab(
                grouped: bySession,
                labelMap: SessionDetector.sessionLabels,
              ),
              _BreakdownTab(
                grouped: bySetup,
                labelMap: TradeSetups.labels,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generateAiSummary(TradeStats stats) async {
    setState(() => _generatingSummary = true);
    final nim = ref.read(nimServiceProvider);
    if (nim == null) {
      setState(() => _generatingSummary = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Configure NIM API key in Settings first.')),
        );
      }
      return;
    }
    try {
      final settings = ref.read(settingsProvider).valueOrNull;
      final balance =
          ref.read(confirmedBalanceProvider).valueOrNull ?? 0.0;
      final pfStr = stats.profitFactor == double.infinity
          ? 'infinite'
          : stats.profitFactor.toStringAsFixed(2);
      final summary = await nim.complete([
        NimService.buildSystemPrompt(
          accountType: settings?.accountType ?? 'usd',
          balance: balance,
          openTradesJson: 'No open trades',
          marginLevelPct: double.infinity,
        ),
        NimMessage(
          role: 'user',
          content: 'Write a brief performance summary: '
              '${stats.wins} wins, ${stats.losses} losses, '
              'win rate ${stats.winRate.toStringAsFixed(1)}%, '
              'net P&L \$${stats.netPnl.toStringAsFixed(2)}, '
              'profit factor $pfStr, '
              'expectancy \$${stats.expectancy.toStringAsFixed(2)}. '
              'Under 100 words, end with one actionable suggestion.',
        ),
      ]);
      setState(() {
        _aiSummary = summary;
        _generatingSummary = false;
      });
    } catch (e) {
      setState(() => _generatingSummary = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI Error: $e')));
      }
    }
  }
}

// ─── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.trades,
    required this.stats,
    required this.aiSummary,
    required this.generatingSummary,
    required this.onGenerateSummary,
    required this.fmt,
  });

  final List<TradeModel> trades;
  final TradeStats stats;
  final String? aiSummary;
  final bool generatingSummary;
  final VoidCallback onGenerateSummary;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    // Build equity curve spots
    double running = 0;
    final equityPoints = <FlSpot>[];
    for (int i = 0; i < trades.length; i++) {
      running += trades[i].pnl ?? 0;
      equityPoints.add(FlSpot(i.toDouble(), running));
    }
    double minY = 0, maxY = 0;
    for (final p in equityPoints) {
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    final yPad = ((maxY - minY) * 0.15).clamp(1.0, double.infinity);
    final chartMinY = minY - yPad;
    final chartMaxY = maxY + yPad;

    final best = trades
        .reduce((a, b) => (a.pnl ?? 0) > (b.pnl ?? 0) ? a : b);
    final worst = trades
        .reduce((a, b) => (a.pnl ?? 0) < (b.pnl ?? 0) ? a : b);
    final pfStr = stats.profitFactor == double.infinity
        ? '\u221e'
        : stats.profitFactor.toStringAsFixed(2);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Primary stats (Win Rate, Net P&L, Profit Factor, Expectancy)
        _StatsGrid(children: [
          _StatCard(
            label: 'Win Rate',
            value: '${stats.winRate.toStringAsFixed(1)}%',
            color: stats.winRate >= 50
                ? AppTheme.primaryGreen
                : AppTheme.dangerRed,
          ),
          _StatCard(
            label: 'Net P&L',
            value:
                '${stats.netPnl >= 0 ? "+" : ""}\$${fmt.format(stats.netPnl)}',
            color: stats.netPnl >= 0
                ? AppTheme.primaryGreen
                : AppTheme.dangerRed,
          ),
          _StatCard(
            label: 'Profit Factor',
            value: pfStr,
            color: stats.profitFactor >= 1.5
                ? AppTheme.primaryGreen
                : stats.profitFactor >= 1.0
                    ? AppTheme.warningYellow
                    : AppTheme.dangerRed,
          ),
          _StatCard(
            label: 'Expectancy',
            value:
                '${stats.expectancy >= 0 ? "+" : ""}\$${fmt.format(stats.expectancy)}',
            color: stats.expectancy >= 0
                ? AppTheme.primaryGreen
                : AppTheme.dangerRed,
          ),
        ]),
        const SizedBox(height: 10),

        // Secondary stats (Avg Win, Avg Loss, Max Drawdown, Avg Hold)
        _StatsGrid(children: [
          _StatCard(
              label: 'Avg Win',
              value: '+\$${fmt.format(stats.avgWin)}',
              color: AppTheme.primaryGreen),
          _StatCard(
              label: 'Avg Loss',
              value: '-\$${fmt.format(stats.avgLoss)}',
              color: AppTheme.dangerRed),
          _StatCard(
              label: 'Max Drawdown',
              value: '\$${fmt.format(stats.maxDrawdown)}',
              color: AppTheme.warningYellow),
          _StatCard(
              label: 'Avg Hold',
              value: _holdLabel(stats.avgHoldingHours),
              color: Colors.white),
        ]),
        const SizedBox(height: 10),

        // Totals row
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                  child: _KV('Total Trades', '${stats.total}')),
              Expanded(
                  child: _KV(
                      'W / L', '${stats.wins} / ${stats.losses}')),
              Expanded(
                  child:
                      _KV('Total Pips', fmt.format(stats.totalPips))),
            ]),
          ),
        ),
        const SizedBox(height: 8),

        // Streaks row
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                  child: _KV('Win Streak',
                      '${stats.longestWinStreak}',
                      color: AppTheme.primaryGreen)),
              Expanded(
                  child: _KV('Loss Streak',
                      '${stats.longestLossStreak}',
                      color: AppTheme.dangerRed)),
            ]),
          ),
        ),
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
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: LineChart(
                    LineChartData(
                      minY: chartMinY,
                      maxY: chartMaxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color:
                              Colors.white.withValues(alpha: 0.05),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 54,
                            getTitlesWidget: (v, _) => Text(
                              '\$${v.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 9),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: equityPoints,
                          isCurved: true,
                          color: stats.netPnl >= 0
                              ? AppTheme.primaryGreen
                              : AppTheme.dangerRed,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: (stats.netPnl >= 0
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

        // Best / Worst trade
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
                    Text('+\$${fmt.format(best.pnl ?? 0)}',
                        style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text(
                        '${best.direction.toUpperCase()} ${best.symbol}',
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
                    Text('\$${fmt.format(worst.pnl ?? 0)}',
                        style: const TextStyle(
                            color: AppTheme.dangerRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text(
                        '${worst.direction.toUpperCase()} ${worst.symbol}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // AI Summary card
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
                if (aiSummary != null)
                  Text(aiSummary!,
                      style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      generatingSummary ? null : onGenerateSummary,
                  icon: generatingSummary
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(generatingSummary
                      ? 'Generating\u2026'
                      : 'Generate AI Summary'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _holdLabel(double hours) {
    if (hours < 1) return '${(hours * 60).toStringAsFixed(0)}m';
    if (hours < 24) return '${hours.toStringAsFixed(1)}h';
    return '${(hours / 24).toStringAsFixed(1)}d';
  }
}

// ─── Breakdown Tab ─────────────────────────────────────────────────────────────

class _BreakdownTab extends StatelessWidget {
  const _BreakdownTab({required this.grouped, this.labelMap});

  final Map<String, TradeStats> grouped;
  final Map<String, String>? labelMap;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.netPnl.compareTo(a.value.netPnl));

    if (sorted.isEmpty) {
      return const Center(
          child:
              Text('No data', style: TextStyle(color: Colors.grey)));
    }

    final maxAbsPnl = sorted
        .map((e) => e.value.netPnl.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, s) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final entry = sorted[i];
        final s = entry.value;
        final label =
            labelMap?[entry.key] ?? entry.key.toUpperCase();
        final isProfit = s.netPnl >= 0;
        final barFraction =
            maxAbsPnl > 0 ? (s.netPnl.abs() / maxAbsPnl) : 0.0;
        final pfStr = s.profitFactor == double.infinity
            ? '\u221e'
            : s.profitFactor.toStringAsFixed(2);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: label + net P&L
                Row(children: [
                  Expanded(
                      child: Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14))),
                  Text(
                    '${isProfit ? "+" : ""}\$${fmt.format(s.netPnl)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isProfit
                            ? AppTheme.primaryGreen
                            : AppTheme.dangerRed),
                  ),
                ]),
                const SizedBox(height: 8),

                // Relative P&L bar
                LayoutBuilder(builder: (_, c) {
                  return Container(
                    height: 4,
                    width: c.maxWidth * barFraction,
                    decoration: BoxDecoration(
                      color: isProfit
                          ? AppTheme.primaryGreen
                          : AppTheme.dangerRed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
                const SizedBox(height: 10),

                // Chips: total trades, win rate, W/L, profit factor
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Chip('${s.total} trades', Colors.grey),
                    _Chip(
                        '${s.winRate.toStringAsFixed(0)}% WR',
                        s.winRate >= 50
                            ? AppTheme.primaryGreen
                            : AppTheme.dangerRed),
                    _Chip('${s.wins}W / ${s.losses}L', Colors.grey),
                    _Chip('PF: $pfStr', Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Shared helper widgets ─────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.2,
        children: children,
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 11)),
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

class _KV extends StatelessWidget {
  const _KV(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color ?? Colors.white)),
        ],
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 11)),
      );
}
