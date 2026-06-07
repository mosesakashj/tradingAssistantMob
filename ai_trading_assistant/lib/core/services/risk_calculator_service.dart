library;

/// Pure-Dart risk calculation utilities.
/// No Flutter dependencies — fully unit-testable.
class RiskCalculatorService {
  RiskCalculatorService._(); // static-only class

  // ── Pip sizes ────────────────────────────────────────────────────────────

  /// Minimum price movement considered 1 pip for a given symbol.
  static double pipSize(String symbol) {
    final s = symbol.toUpperCase();
    if (s == 'XAUUSD') return 0.01;
    if (s == 'XAGUSD') return 0.001;
    if (s.endsWith('JPY')) return 0.01;
    const indices = {'US30', 'NAS100', 'SP500', 'UK100', 'GER40', 'JPN225'};
    if (indices.contains(s)) return 1.0;
    const bigCrypto = {'BTCUSD', 'ETHUSD', 'BNBUSD', 'SOLUSD'};
    if (bigCrypto.contains(s)) return 1.0;
    const smallCrypto = {'XRPUSD', 'LTCUSD'};
    if (smallCrypto.contains(s)) return 0.001;
    return 0.0001; // Standard 4-decimal forex
  }

  // ── Pip value ─────────────────────────────────────────────────────────────

  /// Pip value in account currency per 1.0 standard lot.
  /// For cent accounts multiply result by 0.001.
  static double pipValuePerLot(String symbol, int contractSize) =>
      contractSize * pipSize(symbol);

  // ── Conversions ──────────────────────────────────────────────────────────

  /// Price delta → pips.
  static double toPips(String symbol, double priceDelta) {
    final p = pipSize(symbol);
    return p > 0 ? priceDelta.abs() / p : 0.0;
  }

  /// Pips → price delta.
  static double fromPips(String symbol, double pips) =>
      pips * pipSize(symbol);

  // ── Position sizing ──────────────────────────────────────────────────────

  /// Optimal lot size to risk [dollarRisk] with a [slPips]-pip stop loss.
  static double lotSize({
    required double dollarRisk,
    required double slPips,
    required String symbol,
    required int contractSize,
    bool isCentAccount = false,
  }) {
    if (slPips <= 0 || dollarRisk <= 0) return 0;
    final pvl = pipValuePerLot(symbol, contractSize);
    final effectivePvl = isCentAccount ? pvl / 1000.0 : pvl;
    return effectivePvl > 0 ? dollarRisk / (slPips * effectivePvl) : 0;
  }

  // ── Margin ────────────────────────────────────────────────────────────────

  /// Required margin for a position.
  static double margin({
    required double lots,
    required double entryPrice,
    required int contractSize,
    required int leverage,
    bool isCentAccount = false,
  }) {
    if (leverage <= 0 || lots <= 0 || entryPrice <= 0) return 0;
    final effectiveLots = isCentAccount ? lots / 1000.0 : lots;
    return (effectiveLots * contractSize * entryPrice) / leverage;
  }

  // ── Risk/Reward ───────────────────────────────────────────────────────────

  /// R:R ratio = tpPips / slPips.
  static double rrRatio(double slPips, double tpPips) =>
      slPips > 0 ? tpPips / slPips : 0;

  /// Minimum win rate (0–100 %) to break even at the given R:R.
  static double breakEvenWinRate(double rr) =>
      rr > 0 ? 100.0 / (1.0 + rr) : 100.0;

  // ── P&L ──────────────────────────────────────────────────────────────────

  /// P&L for a position given an absolute price delta (always positive).
  static double pnl({
    required double lots,
    required double priceDelta,
    required int contractSize,
    bool isCentAccount = false,
  }) {
    final effectiveLots = isCentAccount ? lots / 1000.0 : lots;
    return effectiveLots * contractSize * priceDelta;
  }

  // ── Compounding ───────────────────────────────────────────────────────────

  /// Returns balance after each of [periods] periods at [ratePerPeriod].
  /// Index 0 = starting balance.
  static List<double> compound({
    required double startBalance,
    required double ratePerPeriod,
    required int periods,
  }) {
    var bal = startBalance;
    final result = <double>[bal];
    for (int i = 0; i < periods; i++) {
      bal *= (1 + ratePerPeriod);
      result.add(bal);
    }
    return result;
  }
}
