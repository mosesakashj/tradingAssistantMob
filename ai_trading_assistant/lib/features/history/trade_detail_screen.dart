import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/trading_constants.dart';
import '../../core/models/trade_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

class TradeDetailScreen extends ConsumerWidget {
  final String tradeId;

  const TradeDetailScreen({super.key, required this.tradeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closedAsync = ref.watch(closedTradesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete trade',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: closedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (trades) {
          final trade = trades.cast<TradeModel?>().firstWhere(
                (t) => t?.id == tradeId,
                orElse: () => null,
              );
          if (trade == null) {
            return const Center(child: Text('Trade not found'));
          }
          return _DetailBody(trade: trade);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trade'),
        content: const Text('This cannot be undone. Delete this trade?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.dangerRed)),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      final uid = ref.read(currentUserProvider)?.uid;
      if (uid == null) return;
      await ref.read(tradesRepositoryProvider).deleteTrade(uid, tradeId);
      if (context.mounted) Navigator.of(context).pop();
    });
  }
}

class _DetailBody extends StatelessWidget {
  final TradeModel trade;
  const _DetailBody({required this.trade});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('MMM d, yyyy  HH:mm');
    final isBuy = trade.direction == 'buy';
    final isClosed = trade.status == 'closed';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isBuy ? AppTheme.primaryGreen : AppTheme.dangerRed,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${trade.direction.toUpperCase()}  ${trade.symbol}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black),
              ),
            ),
            const SizedBox(width: 10),
            Chip(
              label: Text(
                TradingSymbols.marketLabels[trade.market] ?? trade.market,
                style: const TextStyle(fontSize: 11),
              ),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const Spacer(),
            if (isClosed && trade.pnl != null)
              Text(
                '${trade.pnl! >= 0 ? '+' : ''}\$${fmt.format(trade.pnl)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: trade.pnl! >= 0
                      ? AppTheme.primaryGreen
                      : AppTheme.dangerRed,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Trade Numbers ──────────────────────────────────────────────────
        _card('Trade Details', [
          _row('Lots', trade.lots.toString()),
          _row('Entry Price', trade.entryPrice.toString()),
          if (trade.exitPrice != null)
            _row('Exit Price', trade.exitPrice.toString()),
          if (trade.stopLoss != null) _row('Stop Loss', trade.stopLoss.toString()),
          if (trade.takeProfit != null)
            _row('Take Profit', trade.takeProfit.toString()),
          if (trade.pips != null)
            _row('Pips', '${trade.pips! >= 0 ? '+' : ''}${trade.pips!.toStringAsFixed(1)}'),
          if (trade.riskPercent != null)
            _row('Risk %', '${trade.riskPercent!.toStringAsFixed(2)}%'),
          if (trade.riskRewardPlanned != null)
            _row('Planned RR', '1:${trade.riskRewardPlanned!.toStringAsFixed(1)}'),
        ]),

        // ── Timestamps ────────────────────────────────────────────────────
        _card('Timing', [
          _row('Opened', dateFmt.format(trade.openedAt)),
          if (trade.closedAt != null)
            _row('Closed', dateFmt.format(trade.closedAt!)),
          if (trade.session != 'none')
            _row('Session',
                SessionDetector.sessionLabels[trade.session] ?? trade.session),
          if (trade.setup != 'none')
            _row('Setup',
                TradeSetups.labels[trade.setup] ?? trade.setup),
        ]),

        // ── Emotions ──────────────────────────────────────────────────────
        if (trade.emotionConfidence != null ||
            trade.emotionFear != null ||
            trade.emotionState != null)
          _card('Pre-Trade Emotions', [
            if (trade.emotionConfidence != null)
              _row('Confidence', '${trade.emotionConfidence}/5'),
            if (trade.emotionFear != null)
              _row('Fear', '${trade.emotionFear}/5'),
            if (trade.emotionState != null)
              _row('State', _capitalize(trade.emotionState!)),
          ]),

        // ── Reflection ────────────────────────────────────────────────────
        if (isClosed &&
            (trade.satisfactionScore != null ||
                trade.lessonsLearned != null ||
                trade.mistakeTags.isNotEmpty))
          _card('Trade Reflection', [
            if (trade.satisfactionScore != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 110,
                        child: Text('Satisfaction',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12))),
                    ...List.generate(5, (i) {
                      final star = i + 1;
                      return Icon(
                        star <= (trade.satisfactionScore ?? 0)
                            ? Icons.star
                            : Icons.star_border,
                        color: AppTheme.primaryGreen,
                        size: 20,
                      );
                    }),
                  ],
                ),
              ),
            if (trade.lessonsLearned != null &&
                trade.lessonsLearned!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lessons Learned',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(trade.lessonsLearned!),
                  ],
                ),
              ),
            if (trade.mistakeTags.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mistake Tags',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: trade.mistakeTags.map((tag) {
                      return Chip(
                        label: Text(
                          MistakeTags.labels[tag] ?? tag,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black),
                        ),
                        backgroundColor: AppTheme.dangerRed,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ),
          ]),

        // ── AI Review ────────────────────────────────────────────────────
        if (trade.aiReview != null && trade.aiReview!.isNotEmpty)
          _card('AI Review', [
            Text(
              trade.aiReview!['text']?.toString() ??
                  trade.aiReview!.toString(),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ]),

        // ── Note ─────────────────────────────────────────────────────────
        if (trade.note != null && trade.note!.isNotEmpty)
          _card('Note', [Text(trade.note!)]),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _card(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
