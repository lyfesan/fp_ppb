import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class FirebaseAuthService {
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  // Instantiate FirestoreService to use its methods
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

  // Sign up with email and password - now also takes a name
  static Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name, // Add name parameter
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
        // Optionally, update Firebase Auth profile display name
        await firebaseUser.updateDisplayName(name);
        // It's good to reload the user to ensure the latest data is available
        await firebaseUser.reload();
        firebaseUser = _firebaseAuth.currentUser; // Get the updated user

        // Create the user document in Firestore
        try {
          await _firestoreService.createAppUser(
            firebaseUser: firebaseUser!, // Non-null asserted as we checked
            name: name,
            // photoUrl: null, // Pass a photo URL if you have one at this stage
          );
        } catch (e) {
          // Handle Firestore error, e.g., log it.
          // You might want to decide if the Firebase Auth user should be deleted
          // if Firestore creation fails, which is a more complex scenario.
          if (kDebugMode) {
            print('Firestore user creation failed, but Auth user was created: $e');
          }
        }

        // if (firebaseUser != null && !firebaseUser.emailVerified) {
        //   await firebaseUser.sendEmailVerification();
        //   print('Verification email sent.');
        // }
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to sign up: ${e.message}');
        print('Error code: ${e.code}');
      }
      // If sign-up fails, you might want to return the error or a specific code
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
}