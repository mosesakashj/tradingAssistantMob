import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/trading_constants.dart';
import '../../core/models/trade_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

class ActiveTradesScreen extends ConsumerStatefulWidget {
  const ActiveTradesScreen({super.key});

  @override
  ConsumerState<ActiveTradesScreen> createState() =>
      _ActiveTradesScreenState();
}

class _ActiveTradesScreenState extends ConsumerState<ActiveTradesScreen> {
  final Map<String, TextEditingController> _priceControllers = {};

  @override
  void dispose() {
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String pair) {
    return _priceControllers.putIfAbsent(pair, () => TextEditingController());
  }

  double? _floatingPnl(TradeModel t, double currentPrice) {
    final pnlPerUnit = t.direction == 'buy'
        ? currentPrice - t.entryPrice
        : t.entryPrice - currentPrice;
    final settings = ref.read(settingsProvider).valueOrNull;
    final calc = ref.read(stopoutCalculatorProvider);
    final cs = calc?.contractSizeForSymbol(t.symbol) ?? 100;
    final effectiveLots =
        (settings?.accountType == 'cent') ? t.lots / 1000.0 : t.lots;
    return pnlPerUnit * effectiveLots * cs;
  }

  Future<void> _closeTrade(TradeModel trade, double exitPrice) async {
    final settings = ref.read(settingsProvider).valueOrNull;
    final calc = ref.read(stopoutCalculatorProvider);
    final cs = calc?.contractSizeForSymbol(trade.symbol) ?? 100;
    final effectiveLots =
        (settings?.accountType == 'cent') ? trade.lots / 1000.0 : trade.lots;

    final pnl = (trade.direction == 'buy'
            ? exitPrice - trade.entryPrice
            : trade.entryPrice - exitPrice) *
        effectiveLots *
        cs;
    final pips = (trade.direction == 'buy'
            ? exitPrice - trade.entryPrice
            : trade.entryPrice - exitPrice) /
        0.01;

    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    await ref.read(tradesRepositoryProvider).closeTrade(
          uid,
          id: trade.id,
          exitPrice: exitPrice,
          pnl: pnl,
          pips: pips,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trade closed — P&L: ${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
          ),
          backgroundColor:
              pnl >= 0 ? AppTheme.primaryGreen : AppTheme.dangerRed,
        ),
      );
      _showPostCloseSheet(uid, trade.id);
    }
  }

  void _showPostCloseSheet(String uid, String tradeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PostCloseSheet(
        onSave: (satisfaction, lessons, tags) async {
          await ref.read(tradesRepositoryProvider).updatePostCloseReflection(
                uid,
                id: tradeId,
                satisfactionScore: satisfaction,
                lessonsLearned:
                    lessons.trim().isEmpty ? null : lessons.trim(),
                mistakeTags: tags.isEmpty ? null : tags,
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tradesAsync = ref.watch(openTradesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Active Trades')),
      body: tradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (trades) {
          if (trades.isEmpty) {
            return const Center(
              child: Text(
                'No open trades.\nTap + to open a new position.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          // Group pairs for the current price inputs
          final pairs =
              trades.map((t) => t.symbol).toSet().toList()..sort();

          return Column(
            children: [
              // Current price inputs per pair
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: pairs.map((pair) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextField(
                          controller: _controllerFor(pair),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: '$pair Live Price',
                            hintText: 'e.g. 2350.50',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: trades.length,
                  itemBuilder: (ctx, i) =>
                      _TradeCard(
                    trade: trades[i],
                    currentPrice: double.tryParse(
                        _controllerFor(trades[i].symbol).text),
                    floatingPnl: double.tryParse(
                                _controllerFor(trades[i].symbol).text) !=
                            null
                        ? _floatingPnl(
                            trades[i],
                            double.parse(
                                _controllerFor(trades[i].symbol).text))
                        : null,
                    onClose: (exitPrice) => _closeTrade(trades[i], exitPrice),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TradeCard extends StatelessWidget {
  const _TradeCard({
    required this.trade,
    required this.currentPrice,
    required this.floatingPnl,
    required this.onClose,
  });

  final TradeModel trade;
  final double? currentPrice;
  final double? floatingPnl;
  final Future<void> Function(double exitPrice) onClose;

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.direction == 'buy';
    final fmt = NumberFormat('#,##0.00');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBuy ? AppTheme.primaryGreen : AppTheme.dangerRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${trade.direction.toUpperCase()} ${trade.symbol}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                ),
                const Spacer(),
                if (floatingPnl != null)
                  Text(
                    '${floatingPnl! >= 0 ? '+' : ''}\$${fmt.format(floatingPnl)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: floatingPnl! >= 0
                          ? AppTheme.primaryGreen
                          : AppTheme.dangerRed,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _detail('Lots', trade.lots.toString()),
                _detail('Entry', trade.entryPrice.toString()),
                if (trade.stopLoss != null)
                  _detail('SL', trade.stopLoss.toString()),
                if (trade.takeProfit != null)
                  _detail('TP', trade.takeProfit.toString()),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.dangerRed),
                  foregroundColor: AppTheme.dangerRed,
                ),
                onPressed: currentPrice == null
                    ? null
                    : () => onClose(currentPrice!),
                child: Text(
                  currentPrice == null
                      ? 'Enter live price to close'
                      : 'Close @ ${currentPrice!.toStringAsFixed(2)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post-close reflection bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PostCloseSheet extends StatefulWidget {
  final Future<void> Function(int satisfaction, String lessons, List<String> tags)
      onSave;

  const _PostCloseSheet({required this.onSave});

  @override
  State<_PostCloseSheet> createState() => _PostCloseSheetState();
}

class _PostCloseSheetState extends State<_PostCloseSheet> {
  int _satisfaction = 3;
  final _lessonsCtrl = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _saving = false;

  @override
  void dispose() {
    _lessonsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(
          _satisfaction, _lessonsCtrl.text, _selectedTags.toList());
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Trade Reflection',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Satisfaction stars
            const Text('Satisfaction',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _satisfaction = star),
                  child: Icon(
                    star <= _satisfaction ? Icons.star : Icons.star_border,
                    color: AppTheme.primaryGreen,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Lessons learned
            TextField(
              controller: _lessonsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Lessons Learned (optional)',
                hintText: 'What did you learn from this trade?',
              ),
            ),
            const SizedBox(height: 16),

            // Mistake tags
            const Text('Mistake Tags',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: MistakeTags.all.map((tag) {
                final selected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(
                    MistakeTags.labels[tag] ?? tag,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.black : Colors.white,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppTheme.dangerRed,
                  backgroundColor: Colors.grey.shade800,
                  checkmarkColor: Colors.black,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text('Save Reflection'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
