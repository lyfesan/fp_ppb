import 'package:cloud_firestore/cloud_firestore.dart';

class AccountModel {
  final String id;
  final String name;
  // Constructor
  AccountModel({required this.id, required this.name});

  factory AccountModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AccountModel(
      id: doc.id,
      name: data['name'] ?? '',
    );
  }
}
