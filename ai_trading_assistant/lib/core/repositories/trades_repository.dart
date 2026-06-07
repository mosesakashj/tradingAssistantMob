import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trade_model.dart';

class TradesRepository {
  TradesRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestore.collection('users').doc(uid).collection('trades');

  Stream<List<TradeModel>> watchOpenTrades(String uid) {
    return _col(uid)
        .where('status', isEqualTo: 'open')
        .orderBy('openedAt', descending: false)
        .snapshots()
        .map((qs) => qs.docs.map(TradeModel.fromFirestore).toList());
  }

  Stream<List<TradeModel>> watchClosedTrades(String uid) {
    return _col(uid)
        .where('status', isEqualTo: 'closed')
        .orderBy('closedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(TradeModel.fromFirestore).toList());
  }

  Future<List<TradeModel>> getClosedTrades(String uid) async {
    final qs = await _col(uid)
        .where('status', isEqualTo: 'closed')
        .orderBy('closedAt', descending: true)
        .get();
    return qs.docs.map(TradeModel.fromFirestore).toList();
  }

  Future<String> insertTrade(String uid, TradeModel trade) async {
    final ref = await _col(uid).add(trade.toFirestore());
    return ref.id;
  }

  Future<void> closeTrade(
    String uid, {
    required String id,
    required double exitPrice,
    required double pnl,
    required double pips,
  }) async {
    await _col(uid).doc(id).update({
      'exitPrice': exitPrice,
      'pnl': pnl,
      'pips': pips,
      'status': 'closed',
      'closedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateTrade(String uid, TradeModel trade) async {
    await _col(uid).doc(trade.id).update({
      ...trade.toFirestore(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteTrade(String uid, String id) async {
    await _col(uid).doc(id).delete();
  }

  /// Update post-close reflection fields (satisfaction, lessons, mistake tags).
  Future<void> updatePostCloseReflection(
    String uid, {
    required String id,
    int? satisfactionScore,
    String? lessonsLearned,
    List<String>? mistakeTags,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (satisfactionScore != null) updates['satisfactionScore'] = satisfactionScore;
    if (lessonsLearned != null) updates['lessonsLearned'] = lessonsLearned;
    if (mistakeTags != null) updates['mistakeTags'] = mistakeTags;
    await _col(uid).doc(id).update(updates);
  }
}
