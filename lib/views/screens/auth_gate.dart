import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';
import 'login_screen.dart';
import 'home_page.dart';
import 'navigation_menu.dart';
import 'package:get/get.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listen to authentication state changes from your static service
      stream: FirebaseAuthService.authStateChanges,
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is logged in, show HomePage
        if (snapshot.hasData && snapshot.data != null) {
          // return const HomePage();
          Get.put(NavigationController());
          return NavigationMenu();
        }
        // If user is not logged in, show LoginScreen
        else {
          return const LoginScreen(); // We'll create LoginScreen next
        }
      },
    );
  }
}

/*
  How to use AuthGate:

  In your main.dart, after initializing Firebase, set AuthGate as your home:

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      // options: DefaultFirebaseOptions.currentPlatform, // If you have firebase_options.dart
    );
    runApp(MyApp());
  }

  class MyApp extends StatelessWidget {
    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'Flutter Firebase Auth Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: AuthGate(), // Use AuthGate here
      );
    }
  }
*/
