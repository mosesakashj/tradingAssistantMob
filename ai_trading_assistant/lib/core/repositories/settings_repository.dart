import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/settings_model.dart';

class SettingsRepository {
  SettingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('config');

  Stream<SettingsModel> watchSettings(String uid) {
    return _doc(uid).snapshots().map((snap) {
      if (!snap.exists) return SettingsModel.defaults();
      return SettingsModel.fromFirestore(snap);
    });
  }

  Future<SettingsModel> getSettings(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) return SettingsModel.defaults();
    return SettingsModel.fromFirestore(snap);
  }

  Future<void> upsertSettings(String uid, SettingsModel settings) async {
    await _doc(uid).set(settings.toFirestore(), SetOptions(merge: true));
  }

  Future<void> initializeDefaults(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) {
      await _doc(uid).set(SettingsModel.defaults().toFirestore());
    }
  }
}
