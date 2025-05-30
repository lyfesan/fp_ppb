import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class FirebaseAuthService {
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Private constructor to prevent instantiation, as this is a static class
  FirebaseAuthService._();

  // Stream to listen to authentication state changes
  // This stream emits a User object when the auth state changes (e.g., user logs in or out)
  static Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get the current authenticated user
  static User? get currentUser => _firebaseAuth.currentUser;

  // Sign in with email and password
  // Takes email and password as input
  // Returns a Future<UserCredential> on success, or null on failure
  static Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Attempt to sign in with the provided email and password
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (kDebugMode) {
        print('User signed in: ${userCredential.user?.uid}');
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth exceptions
      if (kDebugMode) {
        print('Failed to sign in: ${e.message}');
        print('Error code: ${e.code}');
      }
      return null;
    } catch (e) {
      // Handle any other exceptions
      if (kDebugMode) {
        print('An unexpected error occurred during sign in: $e');
      }
      return null;
    }
  }

  // Sign up with email and password - now static
  // Takes email and password as input
  // Returns a Future<UserCredential> on success, or null on failure
  static Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Attempt to create a new user with the provided email and password
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (kDebugMode) {
        print('User signed up: ${userCredential.user?.uid}');
      }
      // You might want to send a verification email here
      // if (userCredential.user != null && !userCredential.user!.emailVerified) {
      //   await userCredential.user!.sendEmailVerification();
      //   print('Verification email sent.');
      // }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth exceptions
      if (kDebugMode) {
        print('Failed to sign up: ${e.message}');
        print('Error code: ${e.code}');
      }
      return null;
    } catch (e) {
      // Handle any other exceptions
      if (kDebugMode) {
        print('An unexpected error occurred during sign up: $e');
      }
      return null;
    }
  }

  // Sign out the current user - now static
  // Returns a Future<void>
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
      // Handle any errors during sign out
    }
  }

  // Example: Send Password Reset Email - now static
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
      // Handle errors, e.g., user not found
    } catch (e) {
      if (kDebugMode) {
        print('An unexpected error occurred: $e');
      }
    }
  }

// You can add more static methods here as needed.
}

/*
  How to use this FirebaseAuthService (Static Class):

  1. Add dependencies to your `pubspec.yaml`:
     dependencies:
       flutter:
         sdk: flutter
       firebase_core: ^latest_version // Check pub.dev for latest
       firebase_auth: ^latest_version // Check pub.dev for latest

  2. Initialize Firebase in your `main.dart`:
     import 'package:firebase_core/firebase_core.dart';
     // Make sure you have firebase_options.dart from FlutterFire CLI
     // import 'firebase_options.dart'; // if you have it

     void main() async {
       WidgetsFlutterBinding.ensureInitialized();
       await Firebase.initializeApp(
         // options: DefaultFirebaseOptions.currentPlatform, // if you have firebase_options.dart
       );
       runApp(MyApp());
     }

  3. Since the class is static, you don't need to provide it. You can call methods directly:

     // In your widget:
     // await FirebaseAuthService.signInWithEmailAndPassword(email: 'test@example.com', password: 'password');
     // User? currentUser = FirebaseAuthService.currentUser;

  4. Use the authStateChanges stream to react to login/logout events:
     StreamBuilder<User?>(
       stream: FirebaseAuthService.authStateChanges, // Call the static getter
       builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.active) {
           final User? user = snapshot.data;
           if (user == null) {
             return LoginPage(); // Or your authentication flow start
           }
           return HomePage(); // Or your main app screen
         }
         return Scaffold(body: Center(child: CircularProgressIndicator())); // Loading indicator
       },
     )
*/