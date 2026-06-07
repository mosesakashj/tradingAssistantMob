import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/trading_constants.dart';
import '../../core/models/trade_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/nim_service.dart';
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
        if (isClosed) ...[if (trade.aiReview != null && trade.aiReview!.isNotEmpty)
            _card('AI Review', [
              Text(
                trade.aiReview!['text']?.toString() ??
                    trade.aiReview!.toString(),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ])
          else
            _AiReviewButton(trade: trade),
        ],

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

// ── AI Review Button ──────────────────────────────────────────────────────────

class _AiReviewButton extends ConsumerStatefulWidget {
  const _AiReviewButton({required this.trade});
  final TradeModel trade;

  @override
  ConsumerState<_AiReviewButton> createState() => _AiReviewButtonState();
}

class _AiReviewButtonState extends ConsumerState<_AiReviewButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _requestReview,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppTheme.primaryGreen),
        ),
        icon: _loading
            ? const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_awesome,
                color: AppTheme.primaryGreen, size: 16),
        label: Text(
          _loading ? 'Analysing trade\u2026' : 'Get AI Trade Review',
          style: const TextStyle(color: AppTheme.primaryGreen),
        ),
      ),
    );
  }

  Future<void> _requestReview() async {
    final nim = ref.read(nimServiceProvider);
    if (nim == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Configure NIM API key in Settings first.')),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final settings = ref.read(settingsProvider).valueOrNull;
      final balance =
          ref.read(confirmedBalanceProvider).valueOrNull ?? 0.0;
      final t = widget.trade;

      final parts = <String>[
        'Review this closed trade and give concise coaching feedback.',
        '${t.direction.toUpperCase()} ${t.symbol} (${t.market})',
        'Lots: ${t.lots}  |  Entry: ${t.entryPrice}'
            '${t.exitPrice != null ? '  |  Exit: ${t.exitPrice}' : ''}',
        if (t.pnl != null)
          'Result: ${t.pnl! >= 0 ? '+' : ''}\$${t.pnl!.toStringAsFixed(2)}'
              '${t.pips != null ? '  (${t.pips!.toStringAsFixed(1)} pips)' : ''}',
        if (t.session != 'none') 'Session: ${t.session}',
        if (t.setup != 'none') 'Setup used: ${t.setup}',
        if (t.emotionConfidence != null || t.emotionFear != null)
          'Pre-trade emotions — confidence: ${t.emotionConfidence ?? '?'}/5, '
              'fear: ${t.emotionFear ?? '?'}/5'
              '${t.emotionState != null ? ', state: ${t.emotionState}' : ''}',
        if (t.mistakeTags.isNotEmpty)
          'Mistakes tagged: ${t.mistakeTags.join(', ')}',
        if (t.satisfactionScore != null)
          'Self-satisfaction: ${t.satisfactionScore}/5',
        if (t.lessonsLearned != null && t.lessonsLearned!.isNotEmpty)
          'Lessons noted: ${t.lessonsLearned}',
        '',
        'Structure your response as:\n'
            '**Strengths:** (what went well)\n'
            '**Weaknesses:** (what to improve)\n'
            '**Suggestion:** (one concrete action)\n'
            '**Score:** X/10\n'
            'Max 200 words total.',
      ];

      final systemMsg = NimService.buildSystemPrompt(
        accountType: settings?.accountType ?? 'usd',
        balance: balance,
        openTradesJson: 'Reviewing a closed trade',
        marginLevelPct: double.infinity,
        language: settings?.aiLanguage ?? 'en',
      );

      final result = await nim.complete([
        systemMsg,
        NimMessage(role: 'user', content: parts.join('\n')),
      ]);

      final uid = ref.read(currentUserProvider)?.uid;
      if (uid != null) {
        await ref
            .read(tradesRepositoryProvider)
            .updateTrade(uid, t.copyWith(aiReview: {'text': result}));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
