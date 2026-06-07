import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/wallet_entry_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(walletEntriesProvider);
    final balanceAsync = ref.watch(confirmedBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEntrySheet(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Confirmed Balance',
                    style: TextStyle(color: Colors.grey)),
                balanceAsync.when(
                  loading: () => const CircularProgressIndicator(
                      strokeWidth: 2),
                  error: (e, st) =>
                      const Text('—', style: TextStyle(color: Colors.grey)),
                  data: (balance) => Text(
                    '\$${NumberFormat('#,##0.00').format(balance)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'No wallet entries yet.\nTap + to log a deposit or withdrawal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) => _WalletEntryTile(
                    entry: entries[i],
                    onDelete: () {
                      final uid =
                          ref.read(currentUserProvider)?.uid;
                      if (uid != null) {
                        ref
                            .read(walletRepositoryProvider)
                            .deleteEntry(uid, entries[i].id);
                      }
                    },
                    onToggleStatus: () async {
                      final uid =
                          ref.read(currentUserProvider)?.uid;
                      if (uid == null) return;
                      final newStatus = entries[i].status == 'confirmed'
                          ? 'pending'
                          : 'confirmed';
                      await ref
                          .read(walletRepositoryProvider)
                          .updateEntry(
                            uid,
                            entries[i].copyWith(status: newStatus),
                          );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEntrySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddEntrySheet(
        onSave: (entry) async {
          final uid = ref.read(currentUserProvider)?.uid;
          if (uid != null) {
            await ref.read(walletRepositoryProvider).insertEntry(uid, entry);
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _WalletEntryTile extends StatelessWidget {
  const _WalletEntryTile({
    required this.entry,
    required this.onDelete,
    required this.onToggleStatus,
  });

  final WalletEntryModel entry;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final isDeposit = entry.type == 'deposit';
    final isConfirmed = entry.status == 'confirmed';
    final fmt = NumberFormat('#,##0.00');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isDeposit ? AppTheme.primaryGreen : AppTheme.dangerRed,
          child: Icon(
            isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
            color: Colors.black,
            size: 18,
          ),
        ),
        title: Text(
          '${isDeposit ? '+' : '-'}\$${fmt.format(entry.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDeposit ? AppTheme.primaryGreen : AppTheme.dangerRed,
          ),
        ),
        subtitle: Text(
          '${entry.method ?? entry.type.toUpperCase()} • '
          '${DateFormat('MMM d, yyyy').format(entry.date)}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onToggleStatus,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isConfirmed
                      ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                      : AppTheme.warningYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isConfirmed ? 'Confirmed' : 'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    color: isConfirmed
                        ? AppTheme.primaryGreen
                        : AppTheme.warningYellow,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.grey),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEntrySheet extends StatefulWidget {
  const _AddEntrySheet({required this.onSave});

  final Future<void> Function(WalletEntryModel entry) onSave;

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _methodCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _type = 'deposit';
  String _status = 'confirmed';
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _methodCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + insets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log Wallet Entry',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'deposit', label: Text('Deposit')),
                ButtonSegment(value: 'withdrawal', label: Text('Withdrawal')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (\$)'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid number';
                if (double.parse(v) <= 0) return 'Must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _methodCtrl,
              decoration: const InputDecoration(
                  labelText: 'Method (e.g. Bank Wire, Crypto)'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'confirmed', label: Text('Confirmed')),
                ButtonSegment(value: 'pending', label: Text('Pending')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _saving = true);
                      await widget.onSave(
                        WalletEntryModel(
                          id: '',
                          type: _type,
                          amount: double.parse(_amountCtrl.text),
                          method: _methodCtrl.text.trim().isEmpty
                              ? null
                              : _methodCtrl.text.trim(),
                          status: _status,
                          date: DateTime.now(),
                          note: _noteCtrl.text.trim().isEmpty
                              ? null
                              : _noteCtrl.text.trim(),
                        ),
                      );
                      setState(() => _saving = false);
                    },
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text(
                      _type == 'deposit' ? 'Log Deposit' : 'Log Withdrawal'),
            ),
          ],
        ),
      ),
    );
  }
}
