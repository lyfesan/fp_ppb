import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  // Constructor
  CategoryModel({required this.id, required this.name});

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id, // Mengambil ID dokumen
      name: data['name'] ?? '', // Mengambil field 'name'
    );
  }
}
