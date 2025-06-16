import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:fp_ppb/views/screens/auth/verify_email_screen.dart';
import 'package:get/get.dart';
import 'login_screen.dart';
import '../navigation_menu.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;
        if (user.emailVerified) {
          Get.put(NavigationController());
          return NavigationMenu();
        } else {
          return const VerifyEmailScreen();
        }
      },
    );
  }
}
