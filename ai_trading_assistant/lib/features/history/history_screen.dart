import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/trading_constants.dart';
import '../../core/models/trade_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _filterMarket;
  String? _filterSymbol;
  String? _filterDirection;

  @override
  Widget build(BuildContext context) {
    final tradesAsync = ref.watch(closedTradesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: tradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allTrades) {
          final trades = allTrades.where((t) {
            if (_filterMarket != null && t.market != _filterMarket) return false;
            if (_filterSymbol != null && t.symbol != _filterSymbol) return false;
            if (_filterDirection != null && t.direction != _filterDirection) return false;
            return true;
          }).toList();

          if (trades.isEmpty) {
            return const Center(
              child: Text('No closed trades yet.',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: trades.length,
            itemBuilder: (ctx, i) => _HistoryTile(
              trade: trades[i],
              onTap: () => context.push('/history/${trades[i].id}'),
            ),
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filter Trades',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              const Text('Market',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  _chip(ctx, setModal, 'All', null, _filterMarket, (v) {
                    setState(() {
                      _filterMarket = v;
                      _filterSymbol = null;
                    });
                  }),
                  ...TradingSymbols.marketLabels.entries.map((e) =>
                      _chip(ctx, setModal, e.value, e.key, _filterMarket,
                          (v) {
                        setState(() {
                          _filterMarket = v;
                          _filterSymbol = null;
                        });
                      })),
                ],
              ),
              if (_filterMarket != null) ...[
                const SizedBox(height: 12),
                const Text('Symbol',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip(ctx, setModal, 'All', null, _filterSymbol,
                        (v) => setState(() => _filterSymbol = v)),
                    ...(TradingSymbols.byMarket[_filterMarket!] ?? []).map(
                        (s) => _chip(ctx, setModal, s, s, _filterSymbol,
                            (v) => setState(() => _filterSymbol = v))),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Text('Direction',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  _chip(ctx, setModal, 'All', null, _filterDirection,
                      (v) => setState(() => _filterDirection = v)),
                  _chip(ctx, setModal, 'Buy', 'buy', _filterDirection,
                      (v) => setState(() => _filterDirection = v)),
                  _chip(ctx, setModal, 'Sell', 'sell', _filterDirection,
                      (v) => setState(() => _filterDirection = v)),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterMarket = null;
                    _filterSymbol = null;
                    _filterDirection = null;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext ctx,
    StateSetter setModal,
    String label,
    String? value,
    String? current,
    ValueChanged<String?> onChange,
  ) {
    final selected = current == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        onChange(value);
        setModal(() {});
        Navigator.of(ctx).pop();
      },
      selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
      checkmarkColor: AppTheme.primaryGreen,
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.trade, required this.onTap});
  final TradeModel trade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pnl = trade.pnl ?? 0;
    final fmt = NumberFormat('#,##0.00');
    final isBuy = trade.direction == 'buy';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: isBuy ? AppTheme.primaryGreen : AppTheme.dangerRed,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${trade.direction.toUpperCase()} ${trade.symbol}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (trade.setup != 'none')
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Chip(
                              label: Text(
                                TradeSetups.labels[trade.setup] ??
                                    trade.setup,
                                style: const TextStyle(fontSize: 10),
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        const Spacer(),
                        Text(
                          '${pnl >= 0 ? '+' : ''}\$${fmt.format(pnl)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: pnl >= 0
                                ? AppTheme.primaryGreen
                                : AppTheme.dangerRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Entry ${trade.entryPrice} -> Exit ${trade.exitPrice?.toString() ?? '-'}  |  '
                      '${trade.pips != null ? '${trade.pips!.toStringAsFixed(1)} pips' : ''}  |  '
                      '${trade.lots} lots',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    if (trade.closedAt != null)
                      Text(
                        DateFormat('MMM d, yyyy - HH:mm')
                            .format(trade.closedAt!),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 10),
                      ),
                    if (trade.satisfactionScore != null)
                      Row(
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          return Icon(
                            star <= trade.satisfactionScore!
                                ? Icons.star
                                : Icons.star_border,
                            color: AppTheme.primaryGreen,
                            size: 14,
                          );
                        }),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
