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

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses by Day'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddExpenseScreen()),
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
                // Month selector with label above
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Month',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: selectedMonth,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          // No labelText here since label is above
                        ),
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
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Year selector with label above
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Year',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: selectedYear,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items:
                        years.map((year) {
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
                    ],
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
                print(
                  'Expenses dates: ${expenses.map((e) => e.date).toList()}',
                );

                if (expenses.isEmpty) {
                  return const Center(child: Text('No expenses this month.'));
                }

                // Group expenses by day
                final grouped = <DateTime, List<Expense>>{};
                for (var e in expenses) {
                  final day = DateTime(e.date.year, e.date.month, e.date.day);
                  grouped.putIfAbsent(day, () => []).add(e);
                }

                final sortedDays =
                grouped.keys.toList()..sort((a, b) => a.compareTo(b));

                return ListView.builder(
                  itemCount: sortedDays.length,
                  itemBuilder: (context, index) {
                    final day = sortedDays[index];
                    final dayExpenses = grouped[day]!;
                    final total = dayExpenses.fold<double>(
                      0,
                          (sum, e) =>
                      sum + (double.tryParse(e.amount.toString()) ?? 0),
                    );

                    final formattedTotal = NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(total);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Label
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            DateFormat('EEEE, dd MMMM yyyy').format(day),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Card with background
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DayExpensesScreen(date: day),
                              ),
                            );
                            // print("Tapped on ${day.toIso8601String()}");
                            // Get.to(() => DayExpensesScreen(date: day));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Card(
                              color: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.receipt_long,
                                          color: Colors.grey[700],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${dayExpenses.length} expenses',
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          formattedTotal,
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey[200],
                                          ),
                                          child: Icon(
                                            Icons.chevron_right,
                                            size: 20,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Separator line
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Divider(
                            color: Colors.grey[300],
                            thickness: 1,
                            height: 1,
                          ),
                        ),
                      ],
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
