/// Pure Dart stopout calculator — no Flutter dependencies, fully unit-testable.
library;

class TradeSummary {
  final String pair;
  final double lots;
  final double entryPrice;

  const TradeSummary({
    required this.pair,
    required this.lots,
    required this.entryPrice,
  });
}

class StopoutResult {
  final double usedMargin;
  final double marginLevelPct;
  final double stopoutPrice;
  final double equity;

  const StopoutResult({
    required this.usedMargin,
    required this.marginLevelPct,
    required this.stopoutPrice,
    required this.equity,
  });
}

class StopoutCalculator {
  final int leverage;
  final int contractSizeXauusd;
  final int contractSizeXagusd;
  final int contractSizeForex;
  final int contractSizeIndices;
  final int contractSizeCrypto;
  final double stopoutPct; // e.g. 20.0 for 20%
  final bool isCentAccount;

  const StopoutCalculator({
    required this.leverage,
    required this.contractSizeXauusd,
    required this.contractSizeXagusd,
    this.contractSizeForex = 100000,
    this.contractSizeIndices = 1,
    this.contractSizeCrypto = 1,
    required this.stopoutPct,
    this.isCentAccount = false,
  });

  // Cent accounts divide lot sizes by 1000 before calculations
  double _effectiveLots(double lots) =>
      isCentAccount ? lots / 1000.0 : lots;

  int _contractSize(String pair) {
    final p = pair.toUpperCase();
    if (p == 'XAUUSD') return contractSizeXauusd;
    if (p == 'XAGUSD') return contractSizeXagusd;
    // Crypto
    if (p.contains('BTC') || p.contains('ETH') || p.contains('LTC') ||
        p.contains('XRP') || p.contains('SOL') || p.contains('BNB')) {
      return contractSizeCrypto;
    }
    // Indices
    if (p == 'US30' || p == 'NAS100' || p == 'SP500' || p == 'UK100' ||
        p == 'GER40' || p == 'JPN225') {
      return contractSizeIndices;
    }
    // Default: Forex
    return contractSizeForex;
  }

  /// Public accessor for contract size (used by UI previews).
  int contractSizeForSymbol(String symbol) => _contractSize(symbol);
  double usedMarginForTrade({
    required String pair,
    required double lots,
    required double entryPrice,
  }) {
    final effLots = _effectiveLots(lots);
    final cs = _contractSize(pair);
    return (effLots * cs * entryPrice) / leverage;
  }

  /// Total used margin across all open trades.
  double totalUsedMargin(List<TradeSummary> openTrades) {
    return openTrades.fold(0.0, (sum, t) {
      return sum +
          usedMarginForTrade(
            pair: t.pair,
            lots: t.lots,
            entryPrice: t.entryPrice,
          );
    });
  }

  /// Margin level percentage. Returns infinity when no open trades.
  double marginLevelPct({
    required double equity,
    required List<TradeSummary> openTrades,
  }) {
    final usedMargin = totalUsedMargin(openTrades);
    if (usedMargin == 0) return double.infinity;
    return (equity / usedMargin) * 100.0;
  }

  /// Stopout price for a specific pair given all open trades.
  /// This is the price at which margin level would hit stopoutPct.
  /// Formula: stopoutPrice = equity * leverage / (totalLotsCS * stopoutPct/100)
  double stopoutPriceForPair({
    required String pair,
    required double equity,
    required List<TradeSummary> openTrades,
  }) {
    final pairTrades =
        openTrades.where((t) => t.pair.toUpperCase() == pair.toUpperCase()).toList();
    if (pairTrades.isEmpty) return 0.0;

    final cs = _contractSize(pair);
    final totalLotsCS = pairTrades.fold<double>(
      0.0,
      (sum, t) => sum + _effectiveLots(t.lots) * cs,
    );
    if (totalLotsCS == 0) return 0.0;

    return (equity * leverage) / (totalLotsCS * (stopoutPct / 100.0));
  }

  /// Full result: usedMargin, marginLevel, stopoutPrice for [pair].
  StopoutResult calculate({
    required String pair,
    required double equity,
    required List<TradeSummary> openTrades,
  }) {
    final used = totalUsedMargin(openTrades);
    final level = marginLevelPct(equity: equity, openTrades: openTrades);
    final stopPrice =
        stopoutPriceForPair(pair: pair, equity: equity, openTrades: openTrades);

    return StopoutResult(
      usedMargin: used,
      marginLevelPct: level,
      stopoutPrice: stopPrice,
      equity: equity,
    );
  }
}
