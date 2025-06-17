import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:fp_ppb/views/screens/auth/auth_gate.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    isEmailVerified = FirebaseAuthService.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      _sendVerificationEmail();

      // Check verification status every 3 seconds
      timer = Timer.periodic(
        const Duration(seconds: 3),
            (_) => _checkEmailVerified(),
      );
    }
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await FirebaseAuthService.sendEmailVerification();
      setState(() => canResendEmail = false);
      await Future.delayed(const Duration(seconds: 5));
      if(mounted) setState(() => canResendEmail = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _checkEmailVerified() async {
    await FirebaseAuthService.currentUser?.reload();
    setState(() {
      isEmailVerified = FirebaseAuthService.currentUser?.emailVerified ?? false;
    });

    if (isEmailVerified) {
      timer?.cancel();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()),
              (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Verify Email'),
      // ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.email_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'Check Your Email',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'A verification link has been sent to your email address. Please click the link to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: canResendEmail ? _sendVerificationEmail : null,
                icon: const Icon(Icons.send),
                label: const Text('Resend Email'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  timer?.cancel();
                  FirebaseAuthService.signOut();
                },
                child: const Text('Cancel & Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
