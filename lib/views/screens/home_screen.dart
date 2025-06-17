import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
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
  DateTime? _lastTimeBackButtonWasTapped;

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
  void fetchTopCategories(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    firestoreService
        .getExpensesByCategory(userId: userId, startDate: startOfMonth, endDate: endOfMonth)
        .listen((categoryList) async {
      List<Map<String, dynamic>> updatedList = [];

      for (var category in categoryList.take(5)) {
        final categoryModel = await firestoreService.getExpenseCategoryById(userId, category['categoryId']);
        updatedList.add({
          'categoryId': category['categoryId'],
          'total': category['total'],
          'name': categoryModel?.name ?? 'Unknown',
        });
      }

      if (mounted) {
        setState(() {
          topExpenseCategories = updatedList;
        });
      }
    });

    firestoreService
        .getIncomesByCategory(userId: userId, startDate: startOfMonth, endDate: endOfMonth)
        .listen((categoryList) async {
      List<Map<String, dynamic>> updatedList = [];

      for (var category in categoryList.take(5)) {
        final categoryModel = await firestoreService.getIncomeCategoryById(userId, category['categoryId']);
        updatedList.add({
          'categoryId': category['categoryId'],
          'total': category['total'],
          'name': categoryModel?.name ?? 'Unknown',
        });
      }

      if (mounted) {
        setState(() {
          topIncomeCategories = updatedList;
        });
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

  Widget _buildPieChart(List<Map<String, dynamic>> categories, String title, List<Color> chartColors,) {
    if (categories.isEmpty) {
      return const Center(child: Text("No data available"));
    }

    double total = categories.fold(0.0, (sum, item) => sum + (item['total'] as double));

    List<PieChartSectionData> sections = [];

    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final value = category['total'] as double;
      final name = category['name'] ?? 'Unknown';
      final color = chartColors[i % chartColors.length];

      final percentage = (value / total) * 100;

      sections.add(PieChartSectionData(
        color: color,
        title: '$name\n${percentage.toStringAsFixed(1)}%',
        value: value,
        radius: 80,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text(title, style: Theme.of(context).textTheme.titleMedium),
        // const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 1,
          child: PieChart(
            PieChartData(
              sections: sections,
              borderData: FlBorderData(show: false),
              sectionsSpace: 0,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 5),
        // Horizontal legend
        Center(
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(categories.length, (index) {
              final name = categories[index]['name'] ?? 'Unknown';
              final color = chartColors[index % chartColors.length];

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(name, style: const TextStyle(fontSize: 14)),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildTopCategories(Currency activeCurrency, double exchangeRate) {
    final List<Color> expenseChartColors = [
      Colors.red.shade300,       // softer red
      Colors.deepOrange.shade300,
      Colors.amber.shade300,
      Colors.greenAccent,
      Colors.brown.shade300,
      Colors.deepPurple.shade300,
      Colors.lightBlueAccent,
    ];

    final List<Color> incomeChartColors = [
      Colors.lightBlueAccent,
      Colors.greenAccent,
      Colors.amber.shade300,
      Colors.deepPurple.shade300,
      Colors.red.shade300,       // softer red
      Colors.deepOrange.shade300,
      Colors.brown.shade300,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top 5 Expense Categories (This Month)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        _buildPieChart(topExpenseCategories, '', expenseChartColors),
        const SizedBox(height: 16),
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topExpenseCategories.length,
          itemBuilder: (context, index) {
            final category = topExpenseCategories[index];
            return FutureBuilder<CategoryModel?>(
              future: firestoreService.getExpenseCategoryById(
                  _auth.currentUser!.uid, category['categoryId']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ListTile(title: Text("..."));
                }

                final categoryName = snapshot.data!.name;

                return Column(
                  children: [
                    // Add a divider before every item, including the first
                    const Divider(height: 1),
                    ListTile(
                      leading: Image.asset(
                        'assets/icons/${snapshot.data?.icon ?? 'money.png'}',
                        width: 32,
                        height: 32,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
                      ),
                      title: Text(categoryName),
                      trailing: Text(
                        '- ${formatCurrency(category['total'], activeCurrency, exchangeRate)}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Top 5 Income Categories (This Month)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        _buildPieChart(topIncomeCategories, '', incomeChartColors),
        const SizedBox(height: 16),
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topIncomeCategories.length,
          itemBuilder: (context, index) {
            final category = topIncomeCategories[index];
            return FutureBuilder<CategoryModel?>(
              future: firestoreService.getIncomeCategoryById(
                  _auth.currentUser!.uid, category['categoryId']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ListTile(title: Text("..."));
                }

                final categoryName = snapshot.data!.name;

                return Column(
                  children: [
                    // Add a divider before every item, including the first
                    const Divider(height: 1),
                    ListTile(
                      leading: Image.asset(
                        'assets/icons/${snapshot.data?.icon ?? 'money.png'}',
                        width: 32,
                        height: 32,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
                      ),
                      title: Text(categoryName),
                      trailing: Text(
                        '+ ${formatCurrency(category['total'], activeCurrency, exchangeRate)}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              account.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 40, color: Colors.grey[600]),
                        ],
                      ),
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
                          const SizedBox(width: 15),
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
