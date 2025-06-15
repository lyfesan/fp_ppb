import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fp_ppb/models/account.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fp_ppb/models/currency_model.dart';
import 'package:fp_ppb/services/currency_exchange_service.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../../models/category.dart';
import '../../models/expense.dart';
import '../../models/income.dart';
import 'account/account_screen.dart'; // Import the account screen
import 'navigation_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NavigationController navController = Get.find();
  final CurrencyExchangeService _currencyService = CurrencyExchangeService.instance;
  final PageController _pageController = PageController();

  List<Map<String, dynamic>> topExpenseCategories = [];
  List<Map<String, dynamic>> topIncomeCategories = [];
  List<AccountModel> accounts = [];

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        fetchTopCategories(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<String?> fetchUserName() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final AppUser? appUser = await FirestoreService().getAppUser(user.uid);
      return appUser?.name;
    } catch (e) {
      print("Error fetching user name: $e");
      return null;
    }
  }

  // Fetches top categories, which are independent of the selected account
  void fetchTopCategories(String userId) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    firestoreService
        .getExpensesByCategory(
        userId: userId, startDate: startOfMonth, endDate: endOfMonth)
        .listen((categoryList) {
      if (mounted) {
        setState(() => topExpenseCategories = categoryList.take(3).toList());
      }
    });

    firestoreService
        .getIncomesByCategory(
        userId: userId, startDate: startOfMonth, endDate: endOfMonth)
        .listen((categoryList) {
      if (mounted) {
        setState(() => topIncomeCategories = categoryList.take(3).toList());
      }
    });
  }

  String formatCurrency(
      double value, Currency activeCurrency, double exchangeRate) {
    final convertedValue = value * exchangeRate;
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
    return Scaffold(
      body: ValueListenableBuilder<Currency>(
        valueListenable: _currencyService.activeCurrencyNotifier,
        builder: (context, activeCurrency, child) {
          final exchangeRate = _currencyService.exchangeRateNotifier.value;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildAccountCarousel(activeCurrency, exchangeRate),
                const SizedBox(height: 24),
                _buildTopCategories(activeCurrency, exchangeRate),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return FutureBuilder<String?>(
      future: fetchUserName(),
      builder: (context, snapshot) {
        String name = snapshot.data ?? 'User';
        return Row(
          children: [
            InkWell(
              onTap: () => navController.changeIndex(3),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.person, size: 30),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hello',
                    style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountCarousel(Currency activeCurrency, double exchangeRate) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Center(child: Text("Please log in."));

    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getFinanceAccountStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 220, // Match card height
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No financial accounts found."));
        }

        accounts = snapshot.data!.docs
            .map((doc) => AccountModel.fromFirestore(doc))
            .toList();

        return Column(
          children: [
            SizedBox(
              height: 220, // Increased height to fit details
              child: PageView.builder(
                controller: _pageController,
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  return _BalanceCard(
                    account: accounts[index],
                    userId: userId,
                    activeCurrency: activeCurrency,
                    exchangeRate: exchangeRate,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (accounts.length > 1)
              SmoothPageIndicator(
                controller: _pageController,
                count: accounts.length,
                effect: WormEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  activeDotColor: Theme.of(context).primaryColor,
                  paintStyle: PaintingStyle.stroke,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTopCategories(Currency activeCurrency, double exchangeRate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top 3 Expense Categories (This Month)',
            style: Theme.of(context).textTheme.titleMedium),
        ListView.builder(
          padding: EdgeInsets.zero, // UPDATED: Removed default padding
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topExpenseCategories.length,
          itemBuilder: (context, index) {
            final category = topExpenseCategories[index];
            return FutureBuilder<CategoryModel?>(
              future: firestoreService.getExpenseCategoryById(
                  _auth.currentUser!.uid, category['categoryId']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const ListTile(title: Text("..."));
                final categoryName = snapshot.data!.name;
                return ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(categoryName),
                  trailing: Text(
                    '- ${formatCurrency(category['total'], activeCurrency, exchangeRate)}',
                    style: const TextStyle(fontSize: 15, color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Top 3 Income Categories (This Month)',
            style: Theme.of(context).textTheme.titleMedium),
        ListView.builder(
          padding: EdgeInsets.zero, // UPDATED: Removed default padding
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topIncomeCategories.length,
          itemBuilder: (context, index) {
            final category = topIncomeCategories[index];
            return FutureBuilder<CategoryModel?>(
              future: firestoreService.getIncomeCategoryById(
                  _auth.currentUser!.uid, category['categoryId']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const ListTile(title: Text("..."));
                final categoryName = snapshot.data!.name;
                return ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(categoryName),
                  trailing: Text(
                    '+ ${formatCurrency(category['total'], activeCurrency, exchangeRate)}',
                    style: const TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// A new widget specifically for the balance card in the PageView
class _BalanceCard extends StatelessWidget {
  final AccountModel account;
  final String userId;
  final Currency activeCurrency;
  final double exchangeRate;
  final FirestoreService firestoreService = FirestoreService();

  _BalanceCard({
    required this.account,
    required this.userId,
    required this.activeCurrency,
    required this.exchangeRate,
  });

  String formatCurrency(
      double value, Currency activeCurrency, double exchangeRate) {
    final convertedValue = value * exchangeRate;
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
    // These streams fetch all transactions for THIS specific account
    final expensesStream = firestoreService.getExpensesByAccount(
        userId: userId, accountId: account.id, startDate: DateTime(2000), endDate: DateTime(2100));
    final incomeStream = firestoreService.getIncomeByAccount(
        userId: userId, accountId: account.id, startDate: DateTime(2000), endDate: DateTime(2100));

    // Use nested StreamBuilders to combine streams without Rx
    return StreamBuilder<List<Expense>>(
      stream: expensesStream,
      builder: (context, expenseSnapshot) {
        return StreamBuilder<List<Income>>(
          stream: incomeStream,
          builder: (context, incomeSnapshot) {
            if (!expenseSnapshot.hasData || !incomeSnapshot.hasData) {
              return const Card(child: Center(child: CircularProgressIndicator()));
            }

            final List<Expense> allExpenses = expenseSnapshot.data ?? [];
            final List<Income> allIncomes = incomeSnapshot.data ?? [];

            // Calculate total balance
            final totalExpenses = allExpenses.fold(0.0, (sum, item) => sum + item.amount);
            final totalIncomes = allIncomes.fold(0.0, (sum, item) => sum + item.amount);
            final balance = totalIncomes - totalExpenses;

            // Calculate monthly totals
            final now = DateTime.now();
            final startOfMonth = DateTime(now.year, now.month, 1);
            final endOfMonth = DateTime(now.year, now.month + 1, 0);

            final monthlyExpenses = allExpenses
                .where((e) => e.date.isAfter(startOfMonth) && e.date.isBefore(endOfMonth))
                .fold(0.0, (sum, item) => sum + item.amount);

            final monthlyIncomes = allIncomes
                .where((i) => i.date.isAfter(startOfMonth) && i.date.isBefore(endOfMonth))
                .fold(0.0, (sum, item) => sum + item.amount);

            return GestureDetector( // UPDATED: Added GestureDetector for tap functionality
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountScreen(account: account),
                  ),
                );
              },
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        formatCurrency(balance, activeCurrency, exchangeRate),
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Image.asset("assets/icons/expenses.png", width: 40, height: 40),
                                const SizedBox(width: 15),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Expenses', style: TextStyle(fontSize: 16)),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          formatCurrency(monthlyExpenses, activeCurrency, exchangeRate),
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Image.asset("assets/icons/income.png", width: 40, height: 40),
                                const SizedBox(width: 15),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Income', style: TextStyle(fontSize: 16)),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          formatCurrency(monthlyIncomes, activeCurrency, exchangeRate),
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
