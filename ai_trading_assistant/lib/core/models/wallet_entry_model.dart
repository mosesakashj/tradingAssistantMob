import 'package:cloud_firestore/cloud_firestore.dart';

class WalletEntryModel {
  final String id;
  final String type; // 'deposit' | 'withdrawal'
  final double amount;
  final String status; // 'confirmed' | 'pending'
  final DateTime date;
  final String? method;
  final String? note;

  const WalletEntryModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.date,
    this.method,
    this.note,
  });

  factory WalletEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletEntryModel(
      id: doc.id,
      type: data['type'] as String? ?? 'deposit',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'pending',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      method: data['method'] as String?,
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'amount': amount,
        'status': status,
        'date': Timestamp.fromDate(date),
        'method': method,
        'note': note,
      };

  WalletEntryModel copyWith({
    String? id,
    String? type,
    double? amount,
    String? status,
    DateTime? date,
    String? method,
    String? note,
  }) =>
      WalletEntryModel(
        id: id ?? this.id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        status: status ?? this.status,
        date: date ?? this.date,
        method: method ?? this.method,
        note: note ?? this.note,
      );
}
