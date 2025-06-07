import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/expense.dart';
import '../../../services/firestore_service.dart';
import 'add_expenses_screen.dart';
import 'edit_expenses_screen.dart';


class DayExpensesScreen extends StatelessWidget {
  final DateTime date;

  DayExpensesScreen({super.key, required this.date});

  final FirestoreService firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMMd().format(date)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen()));
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Expense>>(
        stream: firestoreService.getExpenses(
          userId: FirebaseAuth.instance.currentUser!.uid,
          startDate: start,
          endDate: end,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final expenses = snapshot.data!;
          if (expenses.isEmpty) {
            return const Center(child: Text('No expenses for this day.'));
          }

          return ListView.builder(
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final e = expenses[index];
              return ListTile(
                title: Text(e.name),
                subtitle: Text('Category ID: ${e.categoryId}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditExpenseScreen(expense: e),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;

                        await firestoreService.deleteExpense(
                          expenseId: e.id,
                          userId: user.uid,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expense deleted')),
                        );
                      },
                    ),
                  ],
                ),
              );

            },
          );
        },
      ),
    );
  }
}