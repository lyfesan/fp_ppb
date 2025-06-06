import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection reference for users
  // It's good practice to use the UID from Firebase Auth as the document ID

  final CollectionReference<Map<String, dynamic>> usersCollection =
  FirebaseFirestore.instance.collection('users');

  final CollectionReference<Map<String, dynamic>> categories =
  FirebaseFirestore.instance.collection('Category');

  /// Adds a new AppUser to Firestore.
  /// The document ID will be the Firebase Auth User's UID.
  Future<void> createAppUser({
    required fb_auth.User firebaseUser,
    required String name,
    String? photoUrl,
  }) async {
    try {
      final now = DateTime.now();
      AppUser newUser = AppUser(
        id: firebaseUser.uid,
        name: name,
        email: firebaseUser.email!,
        photo: photoUrl ?? firebaseUser.photoURL, // Use provided or Auth photoURL
        createdAt: now, // Or firebaseUser.metadata.creationTime
        updatedAt: now,
      );

      // Set the document in 'users' collection with UID as document ID
      await usersCollection.doc(firebaseUser.uid).set(newUser.toJson());
      if (kDebugMode) {
        print('AppUser created in Firestore with ID: ${firebaseUser.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating AppUser in Firestore: $e');
      }
      // Rethrow or handle as per your app's error strategy
      rethrow;
    }
  }
  /// Read App User
  Future<AppUser?> getAppUser(String uid) async {
    try {
      final docSnapshot = await usersCollection.doc(uid).get();

      if (docSnapshot.exists) {
        // Use the factory constructor to create an AppUser instance
        return AppUser.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting AppUser: $e');
      }
      return null;
    }
  }
  /// Update App User
  Future<void> updateAppUser(String uid, Map<String, dynamic> data) async {
    try {
      // Automatically add the 'updatedAt' field on every update
      final updateData = {
        ...data,
        'updatedAt': Timestamp.now(),
      };

      await usersCollection.doc(uid).update(updateData);
      if (kDebugMode) {
        print('AppUser updated for ID: $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating AppUser: $e');
      }
      rethrow;
    }
  }

  /// Delete App User
  Future<void> deleteAppUser(String uid) async {
    try {
      await usersCollection.doc(uid).delete();
      if (kDebugMode) {
        print('AppUser document deleted from Firestore for ID: $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting AppUser from Firestore: $e');
      }
      rethrow;
    }
  }

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
