import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fp_ppb/models/currency_model.dart';
import 'package:fp_ppb/services/currency_exchange_service.dart';
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
  // Get instance of the currency service
  final CurrencyExchangeService _currencyService = CurrencyExchangeService.instance;
  String? _userId;

  // Flags to manage stream states
  bool _expenseStreamDone = false;
  bool _incomeStreamDone = false;
  bool _expenseStreamDoneMonthly = false;
  bool _incomeStreamDoneMonthly = false;

  late int _selectedMonth;
  late int _selectedYear;
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];
  final List<int> _years = List.generate(10, (index) => DateTime.now().year - 5 + index);

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

  // UPDATED: Helper to format currency based on active selection
  String _formatCurrency(double amount, Currency activeCurrency, double exchangeRate) {
    final convertedValue = amount * exchangeRate;
    final int decimalDigits = activeCurrency.code == 'IDR' ? 0 : 2;
    final format = NumberFormat.currency(
      locale: 'en_US', // Generic locale
      symbol: '${activeCurrency.symbol} ',
      decimalDigits: decimalDigits,
    );
    return format.format(convertedValue);
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.account.name), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final DateTime startDate = DateTime(_selectedYear, _selectedMonth, 1);
    final DateTime endDate = DateTime(_selectedYear, _selectedMonth + 1, 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      // Listen to currency changes and rebuild the entire screen UI
      body: ValueListenableBuilder<Currency>(
        valueListenable: _currencyService.activeCurrencyNotifier,
        builder: (context, activeCurrency, child) {
          final exchangeRate = _currencyService.exchangeRateNotifier.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(_userId!, activeCurrency, exchangeRate),
                const SizedBox(height: 24),
                _buildMonthYearFilter(),
                const SizedBox(height: 24),
                const Text('Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildTransactionList(_userId!, startDate, endDate, activeCurrency, exchangeRate),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(String userId, Currency activeCurrency, double exchangeRate) {
    return StreamBuilder<List<dynamic>>(
      stream: _combineAllTransactions(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerBalanceCard();
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyBalanceCard(activeCurrency, exchangeRate);
        }

        final allTransactions = snapshot.data!;
        double totalIncome = 0;
        double totalExpense = 0;
        for (var transaction in allTransactions) {
          if (transaction is Income) totalIncome += transaction.amount;
          else if (transaction is Expense) totalExpense += transaction.amount;
        }
        double balanceNow = totalIncome - totalExpense;

        final startOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
        final endOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0);
        double monthlyIncome = 0;
        double monthlyExpense = 0;
        for (var transaction in allTransactions) {
          final date = (transaction is Income) ? transaction.date : (transaction as Expense).date;
          if (date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
              date.isBefore(endOfMonth.add(const Duration(days: 1)))) {
            if (transaction is Income) monthlyIncome += transaction.amount;
            else if (transaction is Expense) monthlyExpense += transaction.amount;
          }
        }

        return Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF8F0),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Net Balance', style: TextStyle(fontSize: 16, color: Colors.black54)),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(balanceNow, activeCurrency, exchangeRate),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBalanceMetric('Expenses', monthlyExpense, activeCurrency, exchangeRate, const Color(0xFFFCE8E8), const Color(0xFFE57373), Icons.arrow_downward_rounded),
                  _buildBalanceMetric('Income', monthlyIncome, activeCurrency, exchangeRate, const Color(0xFFE8F5E9), const Color(0xFF81C784), Icons.arrow_upward_rounded),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Combine streams for ALL transactions to calculate total balance
  Stream<List<dynamic>> _combineAllTransactions(String userId) {
    final veryEarlyDate = DateTime(2000, 1, 1);
    final veryLateDate = DateTime(2100, 12, 31);
    final expensesStream = _firestoreService.getExpensesByAccount(userId: userId, startDate: veryEarlyDate, endDate: veryLateDate, accountId: widget.account.id);
    final incomesStream = _firestoreService.getIncomeByAccount(userId: userId, startDate: veryEarlyDate, endDate: veryLateDate, accountId: widget.account.id);

    final controller = StreamController<List<dynamic>>();
    List<Expense> latestExpenses = [];
    List<Income> latestIncomes = [];

    final expenseSub = expensesStream.listen(
          (expenses) {
        latestExpenses = expenses;
        controller.add([...latestExpenses, ...latestIncomes]);
      },
      onError: controller.addError,
      onDone: () => _expenseStreamDone = true,
    );
    final incomeSub = incomesStream.listen(
          (incomes) {
        latestIncomes = incomes;
        controller.add([...latestExpenses, ...latestIncomes]);
      },
      onError: controller.addError,
      onDone: () => _incomeStreamDone = true,
    );

    controller.onCancel = () {
      expenseSub.cancel();
      incomeSub.cancel();
    };
    return controller.stream;
  }

  Widget _buildEmptyBalanceCard(Currency activeCurrency, double exchangeRate) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(color: const Color(0xFFFBF8F0), borderRadius: BorderRadius.circular(16.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Net Balance', style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(_formatCurrency(0, activeCurrency, exchangeRate), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceMetric('Expenses', 0, activeCurrency, exchangeRate, const Color(0xFFFCE8E8), const Color(0xFFE57373), Icons.arrow_downward_rounded),
              _buildBalanceMetric('Income', 0, activeCurrency, exchangeRate, const Color(0xFFE8F5E9), const Color(0xFF81C784), Icons.arrow_upward_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceMetric(String title, double amount, Currency activeCurrency, double exchangeRate, Color bgColor, Color iconColor, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12.0)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatCurrency(amount, activeCurrency, exchangeRate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Other widgets like _buildShimmerBalanceCard, _buildMonthYearFilter, and _buildTransactionTile need to be updated similarly.
  // The full code below includes all necessary changes.

  Widget _buildShimmerBalanceCard() { // This one does not need currency data as it's a placeholder
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 100, height: 16, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Container(width: 200, height: 32, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildShimmerMetric(), _buildShimmerMetric()]),
        ],
      ),
    );
  }

  Widget _buildShimmerMetric() {
    return Column(children: [Container(width: 60, height: 14, color: Colors.grey[300]), const SizedBox(height: 4), Container(width: 80, height: 20, color: Colors.grey[300])]);
  }

  Widget _buildMonthYearFilter() {
    return Row(
      children: [
        Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8.0), border: Border.all(color: Colors.grey[300]!)), child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: _selectedMonth, icon: const Icon(Icons.arrow_drop_down), onChanged: (int? v) => setState(() => _selectedMonth = v!), items: List.generate(12, (i) => DropdownMenuItem<int>(value: i + 1, child: Text(_months[i]))), isExpanded: true)))),
        const SizedBox(width: 16),
        Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8.0), border: Border.all(color: Colors.grey[300]!)), child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: _selectedYear, icon: const Icon(Icons.arrow_drop_down), onChanged: (int? v) => setState(() => _selectedYear = v!), items: _years.map((y) => DropdownMenuItem<int>(value: y, child: Text(y.toString()))).toList(), isExpanded: true)))),
      ],
    );
  }

  Widget _buildTransactionList(String userId, DateTime startDate, DateTime endDate, Currency activeCurrency, double exchangeRate) {
    return StreamBuilder<List<dynamic>>(
      stream: _combineMonthlyTransactions(userId, startDate, endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No transactions for the selected month.', textAlign: TextAlign.center)));

        final transactions = snapshot.data!;
        transactions.sort((a, b) => ((a is Expense) ? a.date : (a as Income).date).compareTo((b is Expense) ? b.date : (b as Income).date) * -1);

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final t = transactions[index];
            if (t is Expense) return _buildTransactionTile(t.name, -t.amount, t.date, t.categoryId, userId, true, activeCurrency, exchangeRate);
            if (t is Income) return _buildTransactionTile(t.name, t.amount, t.date, t.categoryId, userId, false, activeCurrency, exchangeRate);
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Stream<List<dynamic>> _combineMonthlyTransactions(String userId, DateTime startDate, DateTime endDate) {
    final expensesStream = _firestoreService.getExpensesByAccount(userId: userId, startDate: startDate, endDate: endDate, accountId: widget.account.id);
    final incomesStream = _firestoreService.getIncomeByAccount(userId: userId, startDate: startDate, endDate: endDate, accountId: widget.account.id);

    final controller = StreamController<List<dynamic>>();
    List<Expense> latestExpenses = [];
    List<Income> latestIncomes = [];

    final expSub = expensesStream.listen((d) { latestExpenses = d; controller.add([...latestExpenses, ...latestIncomes]); }, onError: controller.addError, onDone: () => _expenseStreamDoneMonthly = true);
    final incSub = incomesStream.listen((d) { latestIncomes = d; controller.add([...latestExpenses, ...latestIncomes]); }, onError: controller.addError, onDone: () => _incomeStreamDoneMonthly = true);

    controller.onCancel = () { expSub.cancel(); incSub.cancel(); };
    return controller.stream;
  }

  Widget _buildTransactionTile(String name, double amount, DateTime date, String categoryId, String userId, bool isExpense, Currency activeCurrency, double exchangeRate) {
    return FutureBuilder<CategoryModel?>(
      future: isExpense ? _firestoreService.getExpenseCategoryById(userId, categoryId) : _firestoreService.getIncomeCategoryById(userId, categoryId),
      builder: (context, snapshot) {
        String categoryName = snapshot.connectionState == ConnectionState.waiting ? 'Loading...' : (snapshot.data?.name ?? 'N/A');

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isExpense ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(isExpense ? Icons.arrow_downward : Icons.arrow_upward, color: isExpense ? Colors.red : Colors.green, size: 24),
            ),
            title: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              Text(categoryName, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(DateFormat('dd MMM').format(date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            trailing: Text(
              _formatCurrency(amount.abs(), activeCurrency, exchangeRate),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isExpense ? Colors.red : Colors.green),
            ),
          ),
        );
      },
    );
  }
}

