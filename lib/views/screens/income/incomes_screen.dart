import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fp_ppb/models/currency_model.dart';
import 'package:fp_ppb/services/currency_exchange_service.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/income.dart';
import '../../../services/firestore_service.dart';
import 'add_incomes_screen.dart';
import 'dayincomes_screen.dart';

class IncomesScreen extends StatefulWidget {
  const IncomesScreen({super.key});

  @override
  State<IncomesScreen> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends State<IncomesScreen> {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  DateTime? _lastTimeBackButtonWasTapped;

  final FirestoreService firestoreService = FirestoreService();
  final CurrencyExchangeService _currencyService = CurrencyExchangeService.instance;

  int daysInMonth(int year, int month) {
    var beginningNextMonth =
    (month < 12) ? DateTime(year, month + 1, 1) : DateTime(year + 1, 1, 1);
    return beginningNextMonth.subtract(const Duration(days: 1)).day;
  }

  // Helper function to format currency based on active selection
  String _formatCurrency(double amount, Currency activeCurrency, double exchangeRate) {
    final convertedValue = amount * exchangeRate;
    final int decimalDigits = activeCurrency.code == 'IDR' ? 0 : 2;
    final format = NumberFormat.currency(
      locale: 'en_US', // Generic locale is fine as we provide the symbol
      symbol: '${activeCurrency.symbol} ',
      decimalDigits: decimalDigits,
    );
    return format.format(convertedValue);
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime(selectedYear, selectedMonth, 1);
    final endDate = DateTime(
      selectedYear,
      selectedMonth,
      daysInMonth(selectedYear, selectedMonth),
      23,
      59,
      59,
    );

    final monthNames = List.generate(
      12,
          (i) => DateFormat.MMMM().format(DateTime(0, i + 1)),
    );
    final years = List.generate(10, (i) => DateTime.now().year - i);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return; // If already popped, do nothing

        final now = DateTime.now();
        final isFirstTap = _lastTimeBackButtonWasTapped == null ||
            now.difference(_lastTimeBackButtonWasTapped!) > const Duration(seconds: 2);

        if (isFirstTap) {
          _lastTimeBackButtonWasTapped = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tap back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // If the second tap is within 2 seconds, close the app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Incomes by Day'), centerTitle: true),
        floatingActionButton: FloatingActionButton(
          shape: const CircleBorder(),
          child: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
            );
          },
        ),
        body: Column(
          children: [
            // Month and year pickers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Month selector
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Month', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: selectedMonth,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: List.generate(12, (index) {
                            return DropdownMenuItem(value: index + 1, child: Text(monthNames[index]));
                          }),
                          onChanged: (value) {
                            if (value != null) setState(() => selectedMonth = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Year selector
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Year', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: years.map((year) {
                            return DropdownMenuItem(value: year, child: Text(year.toString()));
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => selectedYear = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Firestore stream of incomes for selected month
            Expanded(
              child: ValueListenableBuilder<Currency>(
                valueListenable: _currencyService.activeCurrencyNotifier,
                builder: (context, activeCurrency, child) {
                  final exchangeRate = _currencyService.exchangeRateNotifier.value;
                  return StreamBuilder<List<Income>>(
                    stream: firestoreService.getIncome(
                      userId: FirebaseAuth.instance.currentUser!.uid,
                      startDate: startDate,
                      endDate: endDate,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
      
                      final incomes = snapshot.data ?? [];
                      if (incomes.isEmpty) {
                        return const Center(child: Text('No incomes this month.'));
                      }
      
                      // Group incomes by day
                      final grouped = <DateTime, List<Income>>{};
                      for (var e in incomes) {
                        final day = DateTime(e.date.year, e.date.month, e.date.day);
                        grouped.putIfAbsent(day, () => []).add(e);
                      }
      
                      final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a)); // Sort descending
      
                      return ListView.builder(
                        itemCount: sortedDays.length,
                        itemBuilder: (context, index) {
                          final day = sortedDays[index];
                          final dayIncomes = grouped[day]!;
                          final total = dayIncomes.fold<double>(0, (sum, e) => sum + e.amount);
      
                          // Use the new formatting function
                          final formattedTotal = _formatCurrency(total, activeCurrency, exchangeRate);
      
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Text(
                                  DateFormat('EEEE, dd MMMM y').format(day),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => DayIncomesScreen(date: day)),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Card(
                                    color: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(color: Colors.grey[200]!),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.receipt_long, color: Colors.grey[700]),
                                              const SizedBox(width: 12),
                                              Text(
                                                '${dayIncomes.length} incomes',
                                                style: TextStyle(color: Colors.grey[800], fontSize: 16),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                formattedTotal,
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[200]),
                                                child: Icon(Icons.chevron_right, size: 20, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
