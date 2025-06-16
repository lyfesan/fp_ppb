import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/services/currency_exchange_service.dart';
import 'package:fp_ppb/views/screens/auth/auth_gate.dart';
import 'package:fp_ppb/views/themes/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CurrencyExchangeService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoneySense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AuthGate(),
    );
  }
}
