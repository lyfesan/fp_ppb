import 'package:flutter/material.dart';
import 'package:fp_ppb/models/currency_model.dart';
import 'package:fp_ppb/services/currency_exchange_service.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/expense.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import 'add_expenses_screen.dart';
import 'edit_expenses_screen.dart';
import 'package:fp_ppb/models/category.dart';

class DayExpensesScreen extends StatelessWidget {
  final DateTime date;

  DayExpensesScreen({super.key, required this.date});

  final FirestoreService firestoreService = FirestoreService();
  final CurrencyExchangeService _currencyService = CurrencyExchangeService.instance;

  // Helper to format currency based on active selection
  String _formatCurrency(double amount, Currency activeCurrency, double exchangeRate) {
    final convertedValue = amount * exchangeRate;
    final int decimalDigits = activeCurrency.code == 'IDR' ? 0 : 2;
    final format = NumberFormat.currency(
      locale: 'en_US',
      symbol: '${activeCurrency.symbol} ',
      decimalDigits: decimalDigits,
    );
    return format.format(convertedValue);
  }

  @override
  Widget build(BuildContext context) {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses Detail')),
      body: ValueListenableBuilder<Currency>(
        valueListenable: _currencyService.activeCurrencyNotifier,
        builder: (context, activeCurrency, child) {
          final exchangeRate = _currencyService.exchangeRateNotifier.value;

          return StreamBuilder<List<Expense>>(
            stream: firestoreService.getExpenses(
              userId: FirebaseAuth.instance.currentUser!.uid,
              startDate: start,
              endDate: end,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final expenses = snapshot.data!;
              if (expenses.isEmpty) {
                return const Center(child: Text('No expenses for this day.'));
              }

              // Calculate total
              final totalAmount = expenses.fold<double>(0, (sum, e) => sum + e.amount);

              return Column(
                children: [
                  // Date display above list
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      DateFormat('EEEE, dd MMMM y').format(date),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final e = expenses[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditExpenseScreen(expense: e),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Left part: icon + name + category
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.receipt_long, color: Colors.grey[700]),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  e.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Colors.grey[800],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                FutureBuilder<CategoryModel?>(
                                                  future: firestoreService.getExpenseCategoryById(
                                                    FirebaseAuthService.currentUser!.uid,
                                                    e.categoryId,
                                                  ),
                                                  builder: (context, catSnapshot) {
                                                    if (catSnapshot.connectionState == ConnectionState.waiting) {
                                                      return Text('Category: Loading...', style: TextStyle(color: Colors.grey[600]));
                                                    }
                                                    if (catSnapshot.hasError || !catSnapshot.hasData) {
                                                      return Text('Category: Unknown', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600]));
                                                    }
                                                    return Text(
                                                      'Category: ${catSnapshot.data!.name}',
                                                      style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Right part: amount and arrow
                                    Row(
                                      children: [
                                        Text(
                                          _formatCurrency(e.amount, activeCurrency, exchangeRate),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.chevron_right, color: Colors.grey[600]),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Divider and total
                  Divider(thickness: 1, color: Colors.grey[400]),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 50),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        ),
                        Text(
                          _formatCurrency(totalAmount, activeCurrency, exchangeRate),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
