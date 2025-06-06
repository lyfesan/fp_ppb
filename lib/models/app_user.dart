import 'package:cloud_firestore/cloud_firestore.dart'; // Required for Timestamp

class AppUser {
  final String id;
  final String name;
  final String email;
  final String? photo;
  final DateTime? createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.photo,
    this.createdAt,
    required this.updatedAt,
  });

  // Method to convert AppUser instance to a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photo': photo,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Factory constructor to create AppUser from Firestore DocumentSnapshot
  // Useful if you ever need to read this data back into an AppUser object
  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Missing data for AppUser ${doc.id}');
    }
    return AppUser(
      id: doc.id,
      name: data['name'] as String,
      email: data['email'] as String,
      photo: data['photo'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}