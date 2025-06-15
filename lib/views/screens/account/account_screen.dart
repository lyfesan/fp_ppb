import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:intl/intl.dart';
import '../../../models/category.dart';
import '../../../models/expense.dart';
import '../../../models/income.dart';
import '../../../services/firestore_service.dart';
import '../../../models/account.dart';

class AccountScreen extends StatefulWidget {
  final AccountModel account;

  const AccountScreen({super.key, required this.account});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _userId;

  bool _expenseStreamDone = false;
  bool _incomeStreamDone = false;

  bool _expenseStreamDoneMonthly = false;
  bool _incomeStreamDoneMonthly = false;

  late int _selectedMonth;
  late int _selectedYear;
  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  final List<int> _years = List.generate(
      10, (index) => DateTime.now().year - 5 + index);

  @override
  void initState() {
    super.initState();
    _fetchUserId();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  void _fetchUserId() {
    final user = FirebaseAuthService.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
    } else {
      print("User not logged in.");
    }
  }

  // Helper to format currency
  String _formatCurrency(double amount) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatCurrency.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.account.name),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Define the start and end dates for the selected month/year
    final DateTime startDate = DateTime(_selectedYear, _selectedMonth, 1);
    final DateTime endDate =
    DateTime(_selectedYear, _selectedMonth + 1, 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            _buildBalanceCard(_userId!),
            const SizedBox(height: 24),

            // Month and Year Filters
            _buildMonthYearFilter(),
            const SizedBox(height: 24),

            // Transaction List Title
            const Text(
              'Transactions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Transaction List
            _buildTransactionList(_userId!, startDate, endDate),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(String userId) {
    return StreamBuilder<List<dynamic>>(
      stream: _combineAllTransactions(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerBalanceCard(); // Show shimmer while loading
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyBalanceCard(); // Show empty state if no data
        }

        final List<dynamic> allTransactions = snapshot.data!;
        double totalIncome = 0;
        double totalExpense = 0;

        // Calculate total income and expense for the entire period
        for (var transaction in allTransactions) {
          if (transaction is Income) {
            totalIncome += transaction.amount;
          } else if (transaction is Expense) {
            totalExpense += transaction.amount;
          }
        }
        double balanceNow = totalIncome - totalExpense;

        // Calculate income and expense for the selected month (for transaction display)
        final DateTime startOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
        final DateTime endOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0);

        double monthlyIncome = 0;
        double monthlyExpense = 0;

        for (var transaction in allTransactions) {
          DateTime transactionDate;
          if (transaction is Income) {
            transactionDate = transaction.date;
          } else if (transaction is Expense) {
            transactionDate = transaction.date;
          } else {
            continue;
          }

          if (transactionDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
              transactionDate.isBefore(endOfMonth.add(const Duration(days: 1)))) {
            if (transaction is Income) {
              monthlyIncome += transaction.amount;
            } else if (transaction is Expense) {
              monthlyExpense += transaction.amount;
            }
          }
        }

        return Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF8F0),
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha:0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Net Balance',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(balanceNow),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBalanceMetric(
                    'Expenses',
                    monthlyExpense,
                    const Color(0xFFFCE8E8),
                    const Color(0xFFE57373),
                    Icons.arrow_downward_rounded,
                  ),
                  _buildBalanceMetric(
                    'Income',
                    monthlyIncome,
                    const Color(0xFFE8F5E9),
                    const Color(0xFF81C784),
                    Icons.arrow_upward_rounded,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Stream<List<dynamic>> _combineAllTransactions(String userId) {
    // Get a very wide range for all transactions to calculate overall balance
    final DateTime veryEarlyDate = DateTime(2000, 1, 1);
    final DateTime veryLateDate = DateTime(2100, 12, 31);

    final Stream<List<Expense>> expensesStream = _firestoreService.getExpensesByAccount(
      userId: userId,
      startDate: veryEarlyDate,
      endDate: veryLateDate,
      accountId: widget.account.id,
    );

    final Stream<List<Income>> incomesStream = _firestoreService.getIncomeByAccount(
      userId: userId,
      startDate: veryEarlyDate,
      endDate: veryLateDate,
      accountId: widget.account.id,
    );

    final StreamController<List<dynamic>> controller = StreamController<List<dynamic>>();
    List<Expense> latestExpenses = [];
    List<Income> latestIncomes = [];

    // Listen to the expenses stream
    final StreamSubscription<List<Expense>> expenseSubscription = expensesStream.listen(
            (expenses) {
          latestExpenses = expenses;
          // Emit the combined list whenever new data arrives from expenses
          controller.add([...latestExpenses, ...latestIncomes]);
        },
        onError: controller.addError,
        onDone: () {
          // If both streams are done, close the combined stream
          if (_expenseStreamDone && _incomeStreamDone) {
            controller.close();
          }
        }
    );

    // Listen to the incomes stream
    final StreamSubscription<List<Income>> incomeSubscription = incomesStream.listen(
            (incomes) {
          latestIncomes = incomes;
          // Emit the combined list whenever new data arrives from incomes
          controller.add([...latestExpenses, ...latestIncomes]);
        },
        onError: controller.addError,
        onDone: () {
          // If both streams are done, close the combined stream
          if (_expenseStreamDone && _incomeStreamDone) {
            controller.close();
          }
        }
    );

    // Track stream completion states (optional, for explicit controller closing)
    _expenseStreamDone = false;
    _incomeStreamDone = false;
    expenseSubscription.asFuture().whenComplete(() => _expenseStreamDone = true);
    incomeSubscription.asFuture().whenComplete(() => _incomeStreamDone = true);


    // Ensure subscriptions are cancelled when the combined stream is cancelled
    controller.onCancel = () {
      expenseSubscription.cancel();
      incomeSubscription.cancel();
    };

    return controller.stream;
  }

  Widget _buildShimmerBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 16,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 8),
          Container(
            width: 200,
            height: 32,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildShimmerMetric(),
              _buildShimmerMetric(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerMetric() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 14,
          color: Colors.grey[300],
        ),
        const SizedBox(height: 4),
        Container(
          width: 80,
          height: 20,
          color: Colors.grey[300],
        ),
      ],
    );
  }

  Widget _buildEmptyBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F0),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha:0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Net Balance',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(0), // Display 0 if no transactions
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceMetric(
                'Expenses',
                0,
                const Color(0xFFFCE8E8),
                const Color(0xFFE57373),
                Icons.arrow_downward_rounded,
              ),
              _buildBalanceMetric(
                'Income',
                0,
                const Color(0xFFE8F5E9),
                const Color(0xFF81C784),
                Icons.arrow_upward_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildBalanceMetric(
      String title, double amount, Color bgColor, Color iconColor, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              Text(
                _formatCurrency(amount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMonth,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedMonth = newValue!;
                  });
                },
                items: List.generate(12, (index) {
                  return DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(_months[index]),
                  );
                }),
                isExpanded: true,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedYear = newValue!;
                  });
                },
                items: _years.map<DropdownMenuItem<int>>((int year) {
                  return DropdownMenuItem<int>(
                    value: year,
                    child: Text(year.toString()),
                  );
                }).toList(),
                isExpanded: true,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(
      String userId, DateTime startDate, DateTime endDate) {
    return StreamBuilder<List<dynamic>>(
      stream: _combineMonthlyTransactions(userId, startDate, endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'No transactions for the selected month.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Sort transactions by date in descending order
        final List<dynamic> transactions = snapshot.data!;
        transactions.sort((a, b) {
          DateTime dateA = (a is Expense) ? a.date : (a as Income).date;
          DateTime dateB = (b is Expense) ? b.date : (b as Income).date;
          return dateB.compareTo(dateA);
        });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Disable internal scrolling
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            if (transaction is Expense) {
              return _buildTransactionTile(
                transaction.name,
                -transaction.amount, // Negative for expense
                transaction.date,
                transaction.categoryId,
                userId,
                isExpense: true,
              );
            } else if (transaction is Income) {
              return _buildTransactionTile(
                transaction.name,
                transaction.amount,
                transaction.date,
                transaction.categoryId,
                userId,
                isExpense: false,
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }


  Stream<List<dynamic>> _combineMonthlyTransactions(
      String userId, DateTime startDate, DateTime endDate) {
    // Use the new methods that filter by accountId
    final Stream<List<Expense>> expensesStream = _firestoreService.getExpensesByAccount(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      accountId: widget.account.id,
    );


    final Stream<List<Income>> incomesStream = _firestoreService.getIncomeByAccount(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      accountId: widget.account.id,
    );

    final StreamController<List<dynamic>> controller = StreamController<List<dynamic>>();
    List<Expense> latestExpenses = [];
    List<Income> latestIncomes = [];

    // Listen to the expenses stream
    final StreamSubscription<List<Expense>> expenseSubscription = expensesStream.listen(
            (expenses) {
          latestExpenses = expenses;
          // Emit the combined list whenever new data arrives from expenses
          controller.add([...latestExpenses, ...latestIncomes]);
        },
        onError: controller.addError,
        onDone: () {
          // If both streams are done, close the combined stream
          if (_expenseStreamDoneMonthly && _incomeStreamDoneMonthly) {
            controller.close();
          }
        }
    );

    // Listen to the incomes stream
    final StreamSubscription<List<Income>> incomeSubscription = incomesStream.listen(
            (incomes) {
          latestIncomes = incomes;
          // Emit the combined list whenever new data arrives from incomes
          controller.add([...latestExpenses, ...latestIncomes]);
        },
        onError: controller.addError,
        onDone: () {
          // If both streams are done, close the combined stream
          if (_expenseStreamDoneMonthly && _incomeStreamDoneMonthly) {
            controller.close();
          }
        }
    );

    // Track stream completion states for monthly transactions
    _expenseStreamDoneMonthly = false;
    _incomeStreamDoneMonthly = false;
    expenseSubscription.asFuture().whenComplete(() => _expenseStreamDoneMonthly = true);
    incomeSubscription.asFuture().whenComplete(() => _incomeStreamDoneMonthly = true);

    // Ensure subscriptions are cancelled when the combined stream is cancelled
    controller.onCancel = () {
      expenseSubscription.cancel();
      incomeSubscription.cancel();
    };

    return controller.stream;
  }

  Widget _buildTransactionTile(
      String name,
      double amount,
      DateTime date,
      String categoryId,
      String userId, {
        required bool isExpense,
      }) {
    return FutureBuilder<CategoryModel?>(
      future: isExpense
          ? _firestoreService.getExpenseCategoryById(userId, categoryId)
          : _firestoreService.getIncomeCategoryById(userId, categoryId),
      builder: (context, snapshot) {
        String categoryName = snapshot.data?.name ?? 'N/A';
        if (snapshot.connectionState == ConnectionState.waiting) {
          categoryName = 'Loading...';
        } else if (snapshot.hasError) {
          categoryName = 'Error';
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white, // Set background color explicitly
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isExpense ? Colors.red.withValues(alpha:0.1) : Colors.green.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                color: isExpense ? Colors.red : Colors.green,
                size: 24,
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  categoryName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM').format(date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            trailing: Text(
              _formatCurrency(amount.abs()),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isExpense ? Colors.red : Colors.green,
              ),
            ),
          ),
        );
      },
    );
  }
}
