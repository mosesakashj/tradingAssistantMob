import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/trading_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/risk_calculator_service.dart';
import '../../core/theme/app_theme.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Calculator'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryGreen,
          tabs: const [
            Tab(text: 'Position Size'),
            Tab(text: 'Risk / Reward'),
            Tab(text: 'Pip Value'),
            Tab(text: 'Margin'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _PositionSizeTab(),
          _RiskRewardTab(),
          _PipValueTab(),
          _MarginTab(),
        ],
      ),
    );
  }
}

// ─── Shared helpers ────────────────────────────────────────────────────────────

class _SymbolDropdown extends StatelessWidget {
  const _SymbolDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1E1E2E),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (v) => onChanged(v!),
        items: TradingSymbols.allSymbols
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile(this.label, this.value, {this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 17 : 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? AppTheme.primaryGreen : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _numField(
  TextEditingController ctrl,
  String label, {
  ValueChanged<String>? onChanged,
}) =>
    TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );

Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
    );

Widget _resultCard(List<Widget> children) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Results'),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );

// ─── Tab 1: Position Size ──────────────────────────────────────────────────────

class _PositionSizeTab extends ConsumerStatefulWidget {
  const _PositionSizeTab();

  @override
  ConsumerState<_PositionSizeTab> createState() => _PositionSizeTabState();
}

class _PositionSizeTabState extends ConsumerState<_PositionSizeTab> {
  String _symbol = 'XAUUSD';
  final _riskPctCtrl = TextEditingController(text: '2.0');
  final _entryCtrl = TextEditingController();
  final _slCtrl = TextEditingController();

  @override
  void dispose() {
    _riskPctCtrl.dispose();
    _entryCtrl.dispose();
    _slCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(confirmedBalanceProvider).valueOrNull ?? 0.0;
    final settings = ref.watch(settingsProvider).valueOrNull;
    final calculator = ref.watch(stopoutCalculatorProvider);
    final fmt = NumberFormat('#,##0.00');
    final fmt4 = NumberFormat('#,##0.####');

    final riskPct = double.tryParse(_riskPctCtrl.text) ?? 0;
    final entry = double.tryParse(_entryCtrl.text);
    final sl = double.tryParse(_slCtrl.text);
    final dollarRisk = balance * riskPct / 100.0;

    double? slPips, pvl, lots, marginReq;

    if (calculator != null &&
        settings != null &&
        entry != null &&
        sl != null &&
        entry > 0 &&
        sl > 0) {
      final cs = calculator.contractSizeForSymbol(_symbol);
      final isCent = settings.accountType == 'cent';
      slPips = RiskCalculatorService.toPips(_symbol, (entry - sl).abs());
      pvl = RiskCalculatorService.pipValuePerLot(_symbol, cs) *
          (isCent ? 0.001 : 1.0);
      lots = RiskCalculatorService.lotSize(
        dollarRisk: dollarRisk,
        slPips: slPips,
        symbol: _symbol,
        contractSize: cs,
        isCentAccount: isCent,
      );
      marginReq = RiskCalculatorService.margin(
        lots: lots,
        entryPrice: entry,
        contractSize: cs,
        leverage: settings.leverage,
        isCentAccount: isCent,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Balance info banner
        _balanceBanner(balance, fmt),
        const SizedBox(height: 16),

        _sectionLabel('Symbol'),
        _SymbolDropdown(
            value: _symbol, onChanged: (v) => setState(() => _symbol = v)),
        const SizedBox(height: 16),

        _numField(_riskPctCtrl, 'Risk %',
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _numField(_entryCtrl, 'Entry Price',
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _numField(_slCtrl, 'Stop Loss Price',
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 20),

        _resultCard([
          _ResultTile('Dollar Risk', '\$${fmt.format(dollarRisk)}'),
          if (slPips != null)
            _ResultTile('SL Distance', '${fmt4.format(slPips)} pips'),
          if (pvl != null)
            _ResultTile('Pip Value / Lot', '\$${fmt.format(pvl)}'),
          if (lots != null) ...[
            const Divider(height: 20),
            _ResultTile(
              'Recommended Lots',
              lots.toStringAsFixed(2),
              highlight: true,
            ),
            if (marginReq != null)
              _ResultTile('Required Margin', '\$${fmt.format(marginReq)}'),
          ] else
            const Text('Enter entry and stop loss to calculate',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      ],
    );
  }
}

// ─── Tab 2: Risk / Reward ──────────────────────────────────────────────────────

class _RiskRewardTab extends ConsumerStatefulWidget {
  const _RiskRewardTab();

  @override
  ConsumerState<_RiskRewardTab> createState() => _RiskRewardTabState();
}

class _RiskRewardTabState extends ConsumerState<_RiskRewardTab> {
  String _symbol = 'XAUUSD';
  String _direction = 'buy';
  final _lotsCtrl = TextEditingController(text: '0.10');
  final _entryCtrl = TextEditingController();
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();

  @override
  void dispose() {
    _lotsCtrl.dispose();
    _entryCtrl.dispose();
    _slCtrl.dispose();
    _tpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final calculator = ref.watch(stopoutCalculatorProvider);
    final fmt = NumberFormat('#,##0.00');
    final fmt4 = NumberFormat('#,##0.####');

    final lots = double.tryParse(_lotsCtrl.text);
    final entry = double.tryParse(_entryCtrl.text);
    final sl = double.tryParse(_slCtrl.text);
    final tp = double.tryParse(_tpCtrl.text);

    double? slPips, tpPips, rr, breakEven, dollarRisk, dollarProfit;

    if (calculator != null &&
        settings != null &&
        lots != null &&
        entry != null &&
        sl != null &&
        tp != null &&
        lots > 0 &&
        entry > 0 &&
        sl > 0 &&
        tp > 0) {
      final cs = calculator.contractSizeForSymbol(_symbol);
      final isCent = settings.accountType == 'cent';
      slPips = RiskCalculatorService.toPips(_symbol, (entry - sl).abs());
      tpPips = RiskCalculatorService.toPips(_symbol, (entry - tp).abs());
      rr = RiskCalculatorService.rrRatio(slPips, tpPips);
      breakEven = RiskCalculatorService.breakEvenWinRate(rr);
      dollarRisk = RiskCalculatorService.pnl(
          lots: lots,
          priceDelta: (entry - sl).abs(),
          contractSize: cs,
          isCentAccount: isCent);
      dollarProfit = RiskCalculatorService.pnl(
          lots: lots,
          priceDelta: (entry - tp).abs(),
          contractSize: cs,
          isCentAccount: isCent);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('Symbol'),
        _SymbolDropdown(
            value: _symbol, onChanged: (v) => setState(() => _symbol = v)),
        const SizedBox(height: 16),

        // Direction
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: _direction == 'buy'
                      ? AppTheme.primaryGreen
                      : Colors.transparent,
                  foregroundColor:
                      _direction == 'buy' ? Colors.black : Colors.white,
                  side: BorderSide(
                      color: _direction == 'buy'
                          ? AppTheme.primaryGreen
                          : Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => setState(() => _direction = 'buy'),
                child: const Text('BUY',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: _direction == 'sell'
                      ? AppTheme.dangerRed
                      : Colors.transparent,
                  foregroundColor: Colors.white,
                  side: BorderSide(
                      color: _direction == 'sell'
                          ? AppTheme.dangerRed
                          : Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => setState(() => _direction = 'sell'),
                child: const Text('SELL',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _numField(_lotsCtrl, 'Lots', onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _numField(_entryCtrl, 'Entry Price', onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _numField(_slCtrl, 'Stop Loss', onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _numField(_tpCtrl, 'Take Profit', onChanged: (_) => setState(() {})),
        const SizedBox(height: 20),

        _resultCard([
          if (rr != null) ...[
            _ResultTile(
                'SL Distance',
                '${fmt4.format(slPips!)} pips'
                '  →  -\$${fmt.format(dollarRisk!)}'),
            _ResultTile(
                'TP Distance',
                '${fmt4.format(tpPips!)} pips'
                '  →  +\$${fmt.format(dollarProfit!)}'),
            const Divider(height: 20),
            _ResultTile('R:R Ratio', '1 : ${rr.toStringAsFixed(2)}',
                highlight: true),
            _ResultTile(
                'Break-even Win Rate', '${breakEven!.toStringAsFixed(1)}%'),
          ] else
            const Text('Enter all fields to calculate',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      ],
    );
  }
}

// ─── Tab 3: Pip Value ──────────────────────────────────────────────────────────

class _PipValueTab extends ConsumerStatefulWidget {
  const _PipValueTab();

  @override
  ConsumerState<_PipValueTab> createState() => _PipValueTabState();
}

class _PipValueTabState extends ConsumerState<_PipValueTab> {
  String _symbol = 'XAUUSD';
  final _lotsCtrl = TextEditingController(text: '1.00');

  @override
  void dispose() {
    _lotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final calculator = ref.watch(stopoutCalculatorProvider);
    final fmt2 = NumberFormat('#,##0.00');
    final fmt6 = NumberFormat('#,##0.######');

    final lots = double.tryParse(_lotsCtrl.text) ?? 1.0;
    final cs = calculator?.contractSizeForSymbol(_symbol) ?? 100;
    final isCent = settings?.accountType == 'cent';
    final pip = RiskCalculatorService.pipSize(_symbol);
    final pvl = RiskCalculatorService.pipValuePerLot(_symbol, cs) *
        (isCent ? 0.001 : 1.0);
    final totalPipValue = pvl * lots;
    final miniLotPipValue = pvl * 0.01;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('Symbol'),
        _SymbolDropdown(
            value: _symbol, onChanged: (v) => setState(() => _symbol = v)),
        const SizedBox(height: 16),
        _numField(_lotsCtrl, 'Lots', onChanged: (_) => setState(() {})),
        const SizedBox(height: 20),

        _resultCard([
          _ResultTile('Pip Size', fmt6.format(pip)),
          _ResultTile('Contract Size', '$cs units/lot'),
          _ResultTile('Pip Value / 1.0 Lot', '\$${fmt2.format(pvl)}'),
          _ResultTile('Pip Value / 0.01 Lot', '\$${fmt2.format(miniLotPipValue)}'),
          const Divider(height: 20),
          _ResultTile(
            'Pip Value for ${lots.toStringAsFixed(2)} lots',
            '\$${fmt2.format(totalPipValue)}',
            highlight: true,
          ),
        ]),
      ],
    );
  }
}

// ─── Tab 4: Margin ─────────────────────────────────────────────────────────────

class _MarginTab extends ConsumerStatefulWidget {
  const _MarginTab();

  @override
  ConsumerState<_MarginTab> createState() => _MarginTabState();
}

class _MarginTabState extends ConsumerState<_MarginTab> {
  String _symbol = 'XAUUSD';
  final _lotsCtrl = TextEditingController(text: '1.00');
  final _entryCtrl = TextEditingController();

  @override
  void dispose() {
    _lotsCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(confirmedBalanceProvider).valueOrNull ?? 0.0;
    final settings = ref.watch(settingsProvider).valueOrNull;
    final calculator = ref.watch(stopoutCalculatorProvider);
    final fmt = NumberFormat('#,##0.00');

    final lots = double.tryParse(_lotsCtrl.text) ?? 0;
    final entry = double.tryParse(_entryCtrl.text);
    final cs = calculator?.contractSizeForSymbol(_symbol) ?? 100;
    final isCent = settings?.accountType == 'cent';
    final leverage = settings?.leverage ?? 100;

    double? marginReq, marginPct, freeMargin;
    if (entry != null && entry > 0 && lots > 0) {
      marginReq = RiskCalculatorService.margin(
        lots: lots,
        entryPrice: entry,
        contractSize: cs,
        leverage: leverage,
        isCentAccount: isCent,
      );
      marginPct = balance > 0 ? marginReq / balance * 100 : 0;
      freeMargin = balance - marginReq;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _balanceBanner(balance, fmt,
            extra: '  |  Leverage 1:$leverage'),
        const SizedBox(height: 16),

        _sectionLabel('Symbol'),
        _SymbolDropdown(
            value: _symbol, onChanged: (v) => setState(() => _symbol = v)),
        const SizedBox(height: 16),
        _numField(_lotsCtrl, 'Lots', onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _numField(_entryCtrl, 'Entry Price', onChanged: (_) => setState(() {})),
        const SizedBox(height: 20),

        _resultCard([
          if (marginReq != null) ...[
            _ResultTile('Required Margin', '\$${fmt.format(marginReq)}',
                highlight: true),
            _ResultTile('Margin %', '${marginPct!.toStringAsFixed(2)}%'),
            _ResultTile(
              'Free Margin After',
              freeMargin! >= 0
                  ? '\$${fmt.format(freeMargin)}'
                  : '-\$${fmt.format(freeMargin.abs())}',
            ),
            _ResultTile('Contract Size', '$cs units/lot'),
          ] else
            const Text('Enter lots and entry price to calculate',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      ],
    );
  }
}

// ─── Shared widget helpers ─────────────────────────────────────────────────────

Widget _balanceBanner(double balance, NumberFormat fmt, {String extra = ''}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: Colors.grey, size: 16),
          const SizedBox(width: 8),
          Text(
            'Balance: \$${fmt.format(balance)}$extra',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
