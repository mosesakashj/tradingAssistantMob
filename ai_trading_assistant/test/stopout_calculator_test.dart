import 'package:flutter_test/flutter_test.dart';
import 'package:ai_trading_assistant/core/services/stopout_calculator.dart';

void main() {
  group('StopoutCalculator — USD account (leverage 100)', () {
    const calc = StopoutCalculator(
      leverage: 100,
      contractSizeXauusd: 100,
      contractSizeXagusd: 5000,
      stopoutPct: 20.0,
    );

    test('usedMarginForTrade — XAUUSD 1 lot @ 2000', () {
      final margin = calc.usedMarginForTrade(
          pair: 'XAUUSD', lots: 1.0, entryPrice: 2000.0);
      // 1 * 100 * 2000 / 100 = 2000
      expect(margin, closeTo(2000.0, 0.001));
    });

    test('usedMarginForTrade — XAGUSD 0.5 lots @ 25', () {
      final margin = calc.usedMarginForTrade(
          pair: 'XAGUSD', lots: 0.5, entryPrice: 25.0);
      // 0.5 * 5000 * 25 / 100 = 625
      expect(margin, closeTo(625.0, 0.001));
    });

    test('totalUsedMargin — two trades', () {
      final trades = [
        const TradeSummary(pair: 'XAUUSD', lots: 1.0, entryPrice: 2000.0),
        const TradeSummary(pair: 'XAGUSD', lots: 0.5, entryPrice: 25.0),
      ];
      // 2000 + 625 = 2625
      expect(calc.totalUsedMargin(trades), closeTo(2625.0, 0.001));
    });

    test('marginLevelPct — no trades returns infinity', () {
      final level = calc.marginLevelPct(equity: 5000.0, openTrades: []);
      expect(level, equals(double.infinity));
    });

    test('marginLevelPct — 1 XAUUSD lot @ 2000, equity 4000', () {
      final trades = [
        const TradeSummary(pair: 'XAUUSD', lots: 1.0, entryPrice: 2000.0),
      ];
      // usedMargin = 2000, level = 4000/2000 * 100 = 200%
      final level = calc.marginLevelPct(equity: 4000.0, openTrades: trades);
      expect(level, closeTo(200.0, 0.001));
    });

    test('stopoutPrice — XAUUSD 1 lot, equity 4000, stopout 20%', () {
      final trades = [
        const TradeSummary(pair: 'XAUUSD', lots: 1.0, entryPrice: 2000.0),
      ];
      // stopoutPrice = equity * leverage / (lots * CS * stopout%)
      //              = 4000 * 100 / (1 * 100 * 0.20)
      //              = 400000 / 20 = 20000  (simplified example)
      final price = calc.stopoutPriceForPair(
          pair: 'XAUUSD', equity: 4000.0, openTrades: trades);
      expect(price, closeTo(20000.0, 0.001));
    });

    test('stopoutPrice — no trades for pair returns 0', () {
      final price = calc.stopoutPriceForPair(
          pair: 'XAUUSD', equity: 5000.0, openTrades: []);
      expect(price, equals(0.0));
    });
  });

  group('StopoutCalculator — Cent account (leverage 1000)', () {
    const centCalc = StopoutCalculator(
      leverage: 1000,
      contractSizeXauusd: 100,
      contractSizeXagusd: 5000,
      stopoutPct: 20.0,
      isCentAccount: true,
    );

    test('Cent account divides lots by 1000', () {
      // 100 lots on cent = 0.1 effective lots
      final margin = centCalc.usedMarginForTrade(
          pair: 'XAUUSD', lots: 100.0, entryPrice: 2000.0);
      // effectiveLots = 100/1000 = 0.1
      // 0.1 * 100 * 2000 / 1000 = 20
      expect(margin, closeTo(20.0, 0.001));
    });

    test('Cent account marginLevel', () {
      final trades = [
        const TradeSummary(pair: 'XAUUSD', lots: 100.0, entryPrice: 2000.0),
      ];
      // usedMargin = 20, equity = 100, level = 100/20*100 = 500%
      final level =
          centCalc.marginLevelPct(equity: 100.0, openTrades: trades);
      expect(level, closeTo(500.0, 0.001));
    });
  });
}
