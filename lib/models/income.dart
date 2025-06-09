import 'package:cloud_firestore/cloud_firestore.dart';

class Income {
  final String id;
  final String name;
  final DateTime date;
  final double amount;
  final String categoryId;
  final String userId;

  Income({
    required this.id,
    required this.name,
    required this.date,
    required this.amount,
    required this.categoryId,
    required this.userId,
  });

  factory Income.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Income(
      id: doc.id,
      name: data['name'],
      date: (data['date'] as Timestamp).toDate(),
      amount: data['amount'],
      categoryId: data['categoryId'],
      userId: data['userId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'categoryId': categoryId,
      'userId': userId,
    };
  }

  Income copyWith({
    String? id,
    String? name,
    double? amount,
    String? categoryId,
    DateTime? date,
    String? userId,
  }) {
    return Income(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      userId: userId ?? this.userId,
    );
  }
}
