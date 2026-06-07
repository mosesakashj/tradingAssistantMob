library;

import '../models/trade_model.dart';

// ── Data class ────────────────────────────────────────────────────────────────

class TradeStats {
  const TradeStats({
    required this.total,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.netPnl,
    required this.totalPips,
    required this.avgWin,
    required this.avgLoss,
    required this.profitFactor,
    required this.expectancy,
    required this.maxDrawdown,
    required this.avgHoldingHours,
    required this.longestWinStreak,
    required this.longestLossStreak,
  });

  /// Number of closed trades.
  final int total;
  final int wins;
  final int losses;

  /// 0–100 %.
  final double winRate;
  final double netPnl;
  final double totalPips;

  /// Average PnL of winning trades (positive number).
  final double avgWin;

  /// Average absolute PnL of losing trades (positive number).
  final double avgLoss;

  /// Gross profit / gross loss. [double.infinity] when there are no losses.
  final double profitFactor;

  /// Net PnL / total trades.
  final double expectancy;

  /// Maximum peak-to-trough equity drawdown (positive number).
  final double maxDrawdown;

  /// Average hours a trade was held.
  final double avgHoldingHours;

  final int longestWinStreak;
  final int longestLossStreak;

  static const zero = TradeStats(
    total: 0,
    wins: 0,
    losses: 0,
    winRate: 0,
    netPnl: 0,
    totalPips: 0,
    avgWin: 0,
    avgLoss: 0,
    profitFactor: 0,
    expectancy: 0,
    maxDrawdown: 0,
    avgHoldingHours: 0,
    longestWinStreak: 0,
    longestLossStreak: 0,
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

class AnalyticsService {
  AnalyticsService._();

  /// Computes [TradeStats] for the given list of closed trades.
  static TradeStats compute(List<TradeModel> trades) {
    if (trades.isEmpty) return TradeStats.zero;

    final winPnls =
        trades.where((t) => (t.pnl ?? 0) > 0).map((t) => t.pnl!).toList();
    final lossPnls = trades
        .where((t) => (t.pnl ?? 0) < 0)
        .map((t) => t.pnl!.abs())
        .toList();

    final total = trades.length;
    final wins = winPnls.length;
    final losses = lossPnls.length;
    final winRate = total > 0 ? wins / total * 100.0 : 0.0;

    final grossWin = winPnls.fold<double>(0, (s, v) => s + v);
    final grossLoss = lossPnls.fold<double>(0, (s, v) => s + v);
    final netPnl = grossWin - grossLoss;

    final totalPips =
        trades.fold<double>(0, (s, t) => s + (t.pips ?? 0));

    final avgWin = wins > 0 ? grossWin / wins : 0.0;
    final avgLoss = losses > 0 ? grossLoss / losses : 0.0;
    final profitFactor =
        grossLoss > 0 ? grossWin / grossLoss : double.infinity;
    final expectancy = total > 0 ? netPnl / total : 0.0;

    // Max drawdown (peak-to-trough on cumulative equity)
    double peak = 0, equity = 0, maxDD = 0;
    for (final t in trades) {
      equity += t.pnl ?? 0;
      if (equity > peak) peak = equity;
      final dd = peak - equity;
      if (dd > maxDD) maxDD = dd;
    }

    // Average holding time
    final holdingHrs = trades
        .where((t) => t.closedAt != null)
        .map((t) =>
            t.closedAt!.difference(t.openedAt).inMinutes / 60.0)
        .toList();
    final avgHolding = holdingHrs.isEmpty
        ? 0.0
        : holdingHrs.fold<double>(0, (s, v) => s + v) / holdingHrs.length;

    // Win / loss streaks
    int curWin = 0, curLoss = 0, maxWin = 0, maxLoss = 0;
    for (final t in trades) {
      final pnl = t.pnl ?? 0;
      if (pnl > 0) {
        curWin++;
        curLoss = 0;
        if (curWin > maxWin) maxWin = curWin;
      } else if (pnl < 0) {
        curLoss++;
        curWin = 0;
        if (curLoss > maxLoss) maxLoss = curLoss;
      }
    }

    return TradeStats(
      total: total,
      wins: wins,
      losses: losses,
      winRate: winRate,
      netPnl: netPnl,
      totalPips: totalPips,
      avgWin: avgWin,
      avgLoss: avgLoss,
      profitFactor: profitFactor,
      expectancy: expectancy,
      maxDrawdown: maxDD,
      avgHoldingHours: avgHolding,
      longestWinStreak: maxWin,
      longestLossStreak: maxLoss,
    );
  }

  /// Groups trades by a derived key and computes [TradeStats] per group.
  static Map<String, TradeStats> groupBy(
    List<TradeModel> trades,
    String Function(TradeModel) keyOf,
  ) {
    final groups = <String, List<TradeModel>>{};
    for (final t in trades) {
      (groups[keyOf(t)] ??= []).add(t);
    }
    return groups.map((k, v) => MapEntry(k, compute(v)));
  }
}
