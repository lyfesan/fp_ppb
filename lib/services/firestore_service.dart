import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final CollectionReference<Map<String, dynamic>> categories = FirebaseFirestore
      .instance
      .collection('Category');

  Future<void> addCategory(String name) {
    return categories.add({'name': name, 'timestamp': Timestamp.now()});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCategoriesStream() {
    return categories.orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> updateCategory(String docID, String newName) {
    return categories.doc(docID).update({
      'name': newName,
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> deleteCategory(String docID) {
    return categories.doc(docID).delete();
  }
}
