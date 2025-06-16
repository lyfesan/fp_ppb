import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class FirebaseAuthService {
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static final FirestoreService _firestoreService = FirestoreService();

  // Private constructor to prevent instantiation
  FirebaseAuthService._();

  static Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  static User? get currentUser => _firebaseAuth.currentUser;

  static Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential =
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (kDebugMode) {
        print('User signed in: ${userCredential.user?.uid}');
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to sign in: ${e.message}');
        print('Error code: ${e.code}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('An unexpected error occurred during sign in: $e');
      }
      return null;
    }
  }

  // Sign up with email and password
  static Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential userCredential =
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (kDebugMode) {
        print('User signed up: ${userCredential.user?.uid}');
      }

      User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {

        await firebaseUser.updateDisplayName(name);
        await firebaseUser.reload();
        firebaseUser = _firebaseAuth.currentUser;

        // Create the user document in Firestore
        try {
          await _firestoreService.createAppUser(
            firebaseUser: firebaseUser!,
            name: name,
            // photoUrl: null,
          );
        } catch (e) {
          if (kDebugMode) {
            print('Firestore user creation failed, but Auth user was created: $e');
          }
        }

        if (firebaseUser != null && !firebaseUser.emailVerified) {
          await firebaseUser.sendEmailVerification();
          if (kDebugMode) {
            print('Verification email sent.');
          }
        }
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to sign up: ${e.message}');
        print('Error code: ${e.code}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('An unexpected error occurred during sign up: $e');
      }
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      if (kDebugMode) {
        print('User signed out successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
    }
  }

  static Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      if (kDebugMode) {
        print('Password reset email sent to $email');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to send password reset email: ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('An unexpected error occurred: $e');
      }
    }
  }

  static Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (kDebugMode) {
          print('Verification email sent to ${user.email}');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to send verification email: ${e.message}');
      }
    }
  }

  static Future<void> updateUserEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No user currently signed in.');
    }

    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    try {
      await user.reauthenticateWithCredential(cred);

      await user.updateEmail(newEmail);
      //await user.verifyBeforeUpdateEmail(newEmail);
      if (kDebugMode) {
        print('User email updated successfully in Firebase Auth.');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to update email in Firebase Auth: ${e.message}');
      }
      rethrow;
    }
  }

}