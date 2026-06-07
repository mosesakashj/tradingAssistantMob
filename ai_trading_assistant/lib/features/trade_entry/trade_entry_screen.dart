import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/trading_constants.dart';
import '../../core/models/trade_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/nim_service.dart';
import '../../core/services/stopout_calculator.dart';
import '../../core/theme/app_theme.dart';

class TradeEntryScreen extends ConsumerStatefulWidget {
  const TradeEntryScreen({super.key});

  @override
  ConsumerState<TradeEntryScreen> createState() => _TradeEntryScreenState();
}

class _TradeEntryScreenState extends ConsumerState<TradeEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Market & symbol
  String _market = 'metals';
  String _symbol = 'XAUUSD';
  String _direction = 'buy';

  // Session & setup
  String _session = SessionDetector.detect();
  String _setup = 'none';

  // Pre-trade emotions
  int _emotionConfidence = 3;
  int _emotionFear = 2;
  String _emotionState = 'calm';

  final _lotsCtrl = TextEditingController(text: '0.01');
  final _entryPriceCtrl = TextEditingController();
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _riskPctCtrl = TextEditingController();
  final _rrCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _submitting = false;

  // Derived preview values
  double? _requiredMargin;
  double? _pipValue;

  void _recalcPreview() {
    final settings = ref.read(settingsProvider).valueOrNull;
    final calculator = ref.read(stopoutCalculatorProvider);
    if (settings == null || calculator == null) return;

    final lots = double.tryParse(_lotsCtrl.text);
    final entry = double.tryParse(_entryPriceCtrl.text);
    if (lots == null || entry == null || lots <= 0 || entry <= 0) {
      setState(() {
        _requiredMargin = null;
        _pipValue = null;
      });
      return;
    }

    final margin = calculator.usedMarginForTrade(
      pair: _symbol,
      lots: lots,
      entryPrice: entry,
    );

    final cs = calculator.contractSizeForSymbol(_symbol);
    final effectiveLots =
        settings.accountType == 'cent' ? lots / 1000.0 : lots;
    final pv = effectiveLots * cs * 0.01;

    setState(() {
      _requiredMargin = margin;
      _pipValue = pv;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid == null) {
        setState(() => _submitting = false);
        return;
      }
      final lots = double.parse(_lotsCtrl.text);
      final entryPrice = double.parse(_entryPriceCtrl.text);
      final now = DateTime.now();

      final id = await ref.read(tradesRepositoryProvider).insertTrade(
            uid,
            TradeModel(
              id: '',
              symbol: _symbol,
              market: _market,
              direction: _direction,
              lots: lots,
              entryPrice: entryPrice,
              stopLoss: double.tryParse(_slCtrl.text),
              takeProfit: double.tryParse(_tpCtrl.text),
              riskPercent: double.tryParse(_riskPctCtrl.text),
              riskRewardPlanned: double.tryParse(_rrCtrl.text),
              session: _session,
              setup: _setup,
              emotionConfidence: _emotionConfidence,
              emotionFear: _emotionFear,
              emotionState: _emotionState,
              note: _noteCtrl.text.trim().isEmpty
                  ? null
                  : _noteCtrl.text.trim(),
              openedAt: now,
              status: 'open',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Trigger AI risk insight (non-blocking)
      _triggerAiInsight(id, lots, entryPrice);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_symbol $_direction trade opened'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _triggerAiInsight(String tradeId, double lots, double entryPrice) {
    final nim = ref.read(nimServiceProvider);
    final balance = ref.read(confirmedBalanceProvider).valueOrNull ?? 0.0;
    final openTrades = ref.read(openTradesProvider).valueOrNull ?? [];
    final settings = ref.read(settingsProvider).valueOrNull;
    final calculator = ref.read(stopoutCalculatorProvider);
    if (nim == null || calculator == null || settings == null) return;

    final marginLevel = calculator.marginLevelPct(
      equity: balance,
      openTrades: openTrades
          .map((t) => TradeSummary(
                pair: t.symbol,
                lots: t.lots,
                entryPrice: t.entryPrice,
              ))
          .toList(),
    );

    final systemMsg = NimService.buildSystemPrompt(
      accountType: settings.accountType,
      balance: balance,
      openTradesJson:
          '${openTrades.length} open trade(s), latest: $_symbol $_direction $lots lots @ $entryPrice',
      marginLevelPct: marginLevel,
    );

    nim
        .complete([
          systemMsg,
          const NimMessage(
              role: 'user',
              content:
                  'Give me a one-sentence risk assessment for this new trade.'),
        ])
        .then((insight) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('AI: $insight'),
                duration: const Duration(seconds: 6),
                backgroundColor: AppTheme.accentBlue,
              ),
            );
          }
        })
        .catchError((_) {}); // Silently ignore if API key not set
  }

  @override
  void dispose() {
    _lotsCtrl.dispose();
    _entryPriceCtrl.dispose();
    _slCtrl.dispose();
    _tpCtrl.dispose();
    _riskPctCtrl.dispose();
    _rrCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Trade')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Market category tabs ─────────────────────────────────────
            _sectionLabel('Market'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TradingSymbols.marketLabels.entries.map((e) {
                  final selected = _market == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: selected,
                      selectedColor: AppTheme.primaryGreen,
                      labelStyle: TextStyle(
                        color: selected ? Colors.black : Colors.white,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        final symbols = TradingSymbols.byMarket[e.key]!;
                        setState(() {
                          _market = e.key;
                          _symbol = symbols.first;
                        });
                        _recalcPreview();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Symbol picker ─────────────────────────────────────────────
            _sectionLabel('Symbol'),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children:
                  (TradingSymbols.byMarket[_market] ?? []).map((s) {
                final selected = _symbol == s;
                return GestureDetector(
                  onTap: () {
                    setState(() => _symbol = s);
                    _recalcPreview();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primaryGreen
                          : AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primaryGreen
                            : Colors.grey.shade700,
                      ),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.white,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Direction ────────────────────────────────────────────────
            _sectionLabel('Direction'),
            Row(
              children: [
                Expanded(
                    child: _dirBtn(
                        'BUY', 'buy', AppTheme.primaryGreen, Colors.black)),
                const SizedBox(width: 8),
                Expanded(
                    child: _dirBtn(
                        'SELL', 'sell', AppTheme.dangerRed, Colors.white)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Trade Details ─────────────────────────────────────────────
            _sectionLabel('Trade Details'),
            _numField(_lotsCtrl, 'Lot Size',
                onChanged: (_) => _recalcPreview()),
            const SizedBox(height: 12),
            _numField(_entryPriceCtrl, 'Entry Price',
                onChanged: (_) => _recalcPreview()),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child:
                        _numField(_slCtrl, 'Stop Loss', required: false)),
                const SizedBox(width: 12),
                Expanded(
                    child: _numField(_tpCtrl, 'Take Profit',
                        required: false)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child:
                        _numField(_riskPctCtrl, 'Risk %', required: false)),
                const SizedBox(width: 12),
                Expanded(
                    child: _numField(_rrCtrl, 'Planned RR',
                        required: false)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Session ──────────────────────────────────────────────────
            _sectionLabel('Session'),
            DropdownButtonFormField<String>(
              value: _session,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: SessionDetector.sessionLabels.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _session = v ?? 'none'),
            ),
            const SizedBox(height: 16),

            // ── Setup ────────────────────────────────────────────────────
            _sectionLabel('Setup'),
            DropdownButtonFormField<String>(
              value: _setup,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: TradeSetups.labels.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _setup = v ?? 'none'),
            ),
            const SizedBox(height: 16),

            // ── Pre-trade Emotions ────────────────────────────────────────
            _sectionLabel('Pre-Trade Emotions'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _sliderRow(
                        'Confidence',
                        _emotionConfidence,
                        (v) => setState(
                            () => _emotionConfidence = v.round())),
                    const SizedBox(height: 8),
                    _sliderRow(
                        'Fear / Anxiety',
                        _emotionFear,
                        (v) =>
                            setState(() => _emotionFear = v.round())),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _emotionState,
                      decoration: const InputDecoration(
                        labelText: 'Emotional State',
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'calm', child: Text('Calm')),
                        DropdownMenuItem(
                            value: 'confident',
                            child: Text('Confident')),
                        DropdownMenuItem(
                            value: 'anxious', child: Text('Anxious')),
                        DropdownMenuItem(
                            value: 'frustrated',
                            child: Text('Frustrated')),
                        DropdownMenuItem(
                            value: 'excited', child: Text('Excited')),
                      ],
                      onChanged: (v) =>
                          setState(() => _emotionState = v ?? 'calm'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Notes ─────────────────────────────────────────────────────
            TextFormField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 16),

            // ── Live preview card ─────────────────────────────────────────
            if (_requiredMargin != null || _pipValue != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _previewStat(
                        'Required Margin',
                        '\$${NumberFormat('#,##0.00').format(_requiredMargin ?? 0)}',
                      ),
                      const SizedBox(width: 24),
                      _previewStat(
                        'Pip Value',
                        '\$${NumberFormat('#,##0.00').format(_pipValue ?? 0)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Open Trade'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );

  Widget _dirBtn(
          String label, String value, Color bg, Color fg) =>
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor:
              _direction == value ? bg : Colors.transparent,
          foregroundColor: _direction == value ? fg : Colors.white,
          side: BorderSide(
              color: _direction == value ? bg : Colors.grey),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () => setState(() => _direction = value),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Widget _numField(
    TextEditingController ctrl,
    String label, {
    bool required = true,
    ValueChanged<String>? onChanged,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
        validator: required
            ? (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid number';
                if (double.parse(v) <= 0) return 'Must be > 0';
                return null;
              }
            : (v) {
                if (v != null &&
                    v.isNotEmpty &&
                    double.tryParse(v) == null) {
                  return 'Invalid number';
                }
                return null;
              },
      );

  Widget _sliderRow(
          String label, int value, ValueChanged<double> onChanged) =>
      Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(fontSize: 13))),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: AppTheme.primaryGreen,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text('$value/5',
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey)),
          ),
        ],
      );

  Widget _previewStat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen)),
        ],
      );
}
