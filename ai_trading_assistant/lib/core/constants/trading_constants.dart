/// Centralized symbol definitions for all supported trading instruments.
library;

class TradingSymbols {
  static const Map<String, List<String>> byMarket = {
    'metals': ['XAUUSD', 'XAGUSD'],
    'forex': [
      'EURUSD', 'GBPUSD', 'USDJPY', 'USDCHF', 'AUDUSD',
      'USDCAD', 'NZDUSD', 'EURGBP', 'EURJPY', 'GBPJPY',
      'EURAUD', 'EURCHF', 'AUDJPY', 'CADJPY', 'GBPAUD',
    ],
    'crypto': [
      'BTCUSD', 'ETHUSD', 'LTCUSD', 'XRPUSD', 'SOLUSD', 'BNBUSD',
    ],
    'indices': ['US30', 'NAS100', 'SP500', 'UK100', 'GER40', 'JPN225'],
  };

  static const Map<String, String> marketLabels = {
    'metals': 'Metals',
    'forex': 'Forex',
    'crypto': 'Crypto',
    'indices': 'Indices',
  };

  static String marketForSymbol(String symbol) {
    for (final entry in byMarket.entries) {
      if (entry.value.contains(symbol)) return entry.key;
    }
    return 'forex';
  }

  static List<String> get allSymbols =>
      byMarket.values.expand((s) => s).toList();
}

/// Canonical session auto-detection from device local time (UTC offsets approximated).
class SessionDetector {
  static const sessions = ['asian', 'london', 'newyork', 'overlap', 'none'];

  static const Map<String, String> sessionLabels = {
    'asian': 'Asian',
    'london': 'London',
    'newyork': 'New York',
    'overlap': 'London/NY Overlap',
    'none': 'Other / Unknown',
  };

  /// Detects the current session from UTC hour.
  static String detect() {
    final hour = DateTime.now().toUtc().hour;
    // Asian: 00:00–09:00 UTC
    if (hour >= 0 && hour < 9) return 'asian';
    // London: 07:00–16:00 UTC (with overlap from 13:00)
    if (hour >= 7 && hour < 13) return 'london';
    // Overlap London/NY: 13:00–16:00 UTC
    if (hour >= 13 && hour < 16) return 'overlap';
    // New York: 13:00–22:00 UTC
    if (hour >= 16 && hour < 22) return 'newyork';
    return 'none';
  }
}

/// Standard trade setup names.
class TradeSetups {
  static const List<String> presets = [
    'none',
    'breakout',
    'pullback',
    'reversal',
    'trend_continuation',
    'sr_bounce',
  ];

  static const Map<String, String> labels = {
    'none': 'None',
    'breakout': 'Breakout',
    'pullback': 'Pullback',
    'reversal': 'Reversal',
    'trend_continuation': 'Trend Continuation',
    'sr_bounce': 'S&R Bounce',
  };
}

/// Standard mistake tag definitions.
class MistakeTags {
  static const List<String> all = [
    'entered_early',
    'moved_stop_loss',
    'over_leveraged',
    'revenge_trade',
    'fomo_trade',
    'added_to_loser',
    'closed_winner_early',
    'ignored_plan',
  ];

  static const Map<String, String> labels = {
    'entered_early': 'Entered Early',
    'moved_stop_loss': 'Moved Stop Loss',
    'over_leveraged': 'Over Leveraged',
    'revenge_trade': 'Revenge Trade',
    'fomo_trade': 'FOMO Trade',
    'added_to_loser': 'Added to Loser',
    'closed_winner_early': 'Closed Winner Early',
    'ignored_plan': 'Ignored Trading Plan',
  };
}
