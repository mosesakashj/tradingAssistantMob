import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/settings_model.dart';
import '../models/trade_model.dart';
import '../models/wallet_entry_model.dart';
import '../repositories/settings_repository.dart';
import '../repositories/trades_repository.dart';
import '../repositories/wallet_repository.dart';
import '../services/nim_service.dart';
import '../services/stopout_calculator.dart';

// ── Firestore instance ────────────────────────────────────────────────────────

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// ── Auth state ────────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

// ── Repository providers ──────────────────────────────────────────────────────

final tradesRepositoryProvider = Provider<TradesRepository>((ref) {
  return TradesRepository(ref.watch(firestoreProvider));
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(firestoreProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(firestoreProvider));
});

// ── Settings stream ───────────────────────────────────────────────────────────

final settingsProvider = StreamProvider<SettingsModel>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(SettingsModel.defaults());
  return ref.watch(settingsRepositoryProvider).watchSettings(user.uid);
});

// ── Open trades stream ────────────────────────────────────────────────────────

final openTradesProvider = StreamProvider<List<TradeModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(tradesRepositoryProvider).watchOpenTrades(user.uid);
});

// ── Closed trades stream ──────────────────────────────────────────────────────

final closedTradesProvider = StreamProvider<List<TradeModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(tradesRepositoryProvider).watchClosedTrades(user.uid);
});

// ── Wallet entries stream ─────────────────────────────────────────────────────

final walletEntriesProvider = StreamProvider<List<WalletEntryModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(walletRepositoryProvider).watchAll(user.uid);
});

// ── Confirmed balance stream ──────────────────────────────────────────────────

final confirmedBalanceProvider = StreamProvider<double>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(0.0);
  final settings = ref.watch(settingsProvider).valueOrNull;
  final startingCapital = settings?.startingCapital ?? 0.0;
  return ref
      .watch(walletRepositoryProvider)
      .watchConfirmedBalance(user.uid, startingCapital);
});

// ── NimService provider ───────────────────────────────────────────────────────

final nimServiceProvider = Provider<NimService?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null) return null;
  return NimService(
    baseUrl: settings.nimBaseUrl,
    model: settings.nimModel,
    temperature: settings.nimTemperature,
  );
});

// ── StopoutCalculator provider ────────────────────────────────────────────────

final stopoutCalculatorProvider = Provider<StopoutCalculator?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null) return null;
  return StopoutCalculator(
    leverage: settings.leverage,
    contractSizeXauusd: settings.contractSizeXauusd,
    contractSizeXagusd: settings.contractSizeXagusd,
    contractSizeForex: settings.contractSizeForex,
    contractSizeIndices: settings.contractSizeIndices,
    contractSizeCrypto: settings.contractSizeCrypto,
    stopoutPct: settings.stopoutPct,
    isCentAccount: settings.accountType == 'cent',
  );
});
