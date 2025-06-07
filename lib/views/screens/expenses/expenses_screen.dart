import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/expense.dart';
import '../../../services/firestore_service.dart';
import 'add_expenses_screen.dart';
import 'dayexpenses_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  final FirestoreService firestoreService = FirestoreService();

  int daysInMonth(int year, int month) {
    var beginningNextMonth =
    (month < 12) ? DateTime(year, month + 1, 1) : DateTime(year + 1, 1, 1);
    return beginningNextMonth.subtract(const Duration(days: 1)).day;
  }

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime(selectedYear, selectedMonth, 1);
    final endDate = DateTime(selectedYear, selectedMonth, daysInMonth(selectedYear, selectedMonth), 23, 59, 59);

    final monthNames = List.generate(12, (i) => DateFormat.MMMM().format(DateTime(0, i + 1)));
    final years = List.generate(10, (i) => DateTime.now().year - i);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses by Day'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen()));
        },
      ),
      body: Column(
        children: [
          // Month and year pickers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedMonth,
                    items: List.generate(12, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text(monthNames[index]),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedMonth = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedYear,
                    items: years.map((year) {
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedYear = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Firestore stream of expenses for selected month
          Expanded(
            child: StreamBuilder<List<Expense>>(
              stream: firestoreService.getExpenses(
                userId: FirebaseAuth.instance.currentUser!.uid,
                startDate: startDate,
                endDate: endDate,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final expenses = snapshot.data ?? [];
                print('Expenses count: ${expenses.length}');
                print('Expenses dates: ${expenses.map((e) => e.date).toList()}');

                if (expenses.isEmpty) {
                  return const Center(child: Text('No expenses this month.'));
                }

                // Group expenses by day
                final grouped = <DateTime, List<Expense>>{};
                for (var e in expenses) {
                  final day = DateTime(e.date.year, e.date.month, e.date.day);
                  grouped.putIfAbsent(day, () => []).add(e);
                }

                final sortedDays = grouped.keys.toList()
                  ..sort((a, b) => a.compareTo(b));

                return ListView.builder(
                  itemCount: sortedDays.length,
                  itemBuilder: (context, index) {
                    final day = sortedDays[index];
                    final dayExpenses = grouped[day]!;
                    final total = dayExpenses.fold<double>(
                      0,
                      (sum, e) => sum + (double.tryParse(e.amount) ?? 0),
                    );

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DayExpensesScreen(date: day),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    DateFormat('EEE, dd').format(day),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    '${dayExpenses.length} expenses - Rp. ${total.toStringAsFixed(2)}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}