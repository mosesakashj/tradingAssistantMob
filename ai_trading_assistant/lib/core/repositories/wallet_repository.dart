import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/wallet_entry_model.dart';

class WalletRepository {
  WalletRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestore.collection('users').doc(uid).collection('wallet');

  Stream<List<WalletEntryModel>> watchAll(String uid) {
    return _col(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(WalletEntryModel.fromFirestore).toList());
  }

  Stream<double> watchConfirmedBalance(String uid, double startingCapital) {
    return _col(uid)
        .where('status', isEqualTo: 'confirmed')
        .snapshots()
        .map((qs) {
      double balance = startingCapital;
      for (final doc in qs.docs) {
        final entry = WalletEntryModel.fromFirestore(doc);
        if (entry.type == 'deposit') {
          balance += entry.amount;
        } else {
          balance -= entry.amount;
        }
      }
      return balance;
    });
  }

  Future<void> insertEntry(String uid, WalletEntryModel entry) async {
    await _col(uid).add(entry.toFirestore());
  }

  Future<void> updateEntry(String uid, WalletEntryModel entry) async {
    await _col(uid).doc(entry.id).update(entry.toFirestore());
  }

  Future<void> deleteEntry(String uid, String id) async {
    await _col(uid).doc(id).delete();
  }
}
