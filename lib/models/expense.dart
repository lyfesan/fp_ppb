import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String name;
  final DateTime date;
  final double amount;
  final String accountId;
  final String categoryId;
  final String userId;

  // Constructor
  Expense({
    required this.id,
    required this.name,
    required this.date,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    required this.userId,
  });

  // Convert Firestore document to Expense object
  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      name: data['name'],
      date: (data['date'] as Timestamp).toDate(),
      amount: data['amount'],
      accountId: data['accountId'],
      categoryId: data['categoryId'],
      userId: data['userId'],
    );
  }

  // Convert Expense object to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'accountId': accountId,
      'categoryId': categoryId,
      'userId': userId,
    };
  }

  Expense copyWith({
    String? id,
    String? name,
    double? amount,
    String? accountId,
    String? categoryId,
    DateTime? date,
    String? userId,
  }) {
    return Expense(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      userId: userId ?? this.userId,
    );
  }
}
