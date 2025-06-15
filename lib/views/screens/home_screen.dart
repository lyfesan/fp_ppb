import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../../models/category.dart';
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

  double income = 0.0;
  double expenses = 0.0;
  bool isLoading = true;
  List<Map<String, dynamic>> topExpenseCategories = [];
  List<Map<String, dynamic>> topIncomeCategories = [];

  @override
  void initState() {
    super.initState();
    fetchBalanceData();
  }

  Future<String?> fetchUserName() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // final userDoc = FirestoreService().getAppUser(user.uid);
    //     // await FirebaseFirestore.instance
    //     //     .collection('users')
    //     //     .doc(user.uid)
    //     //     .get();
    //
    // return userDoc.exists ? userDoc['name'] : null;

    try {
      final AppUser? appUser = await FirestoreService().getAppUser(user.uid);
      return appUser?.name;
    } catch (e) {
      print("Error fetching user name: $e");
      return null;
    }
  }

  Future<void> fetchBalanceData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    double tempExpenses = 0;
    double tempIncome = 0;

    firestoreService
        .getExpenses(
          userId: user.uid,
          startDate: startOfMonth,
          endDate: endOfMonth,
        )
        .listen((expenseList) {
          print('Income fetched: $expenseList');
          tempExpenses = expenseList.fold(
            0,
            (sum, expense) => sum + (expense.amount),
          );
          setState(() {
            expenses = tempExpenses;
          });
        });

    firestoreService
        .getIncome(
          userId: user.uid,
          startDate: startOfMonth,
          endDate: endOfMonth,
        )
        .listen((incomeList) {
          print('Income fetched: $incomeList');
          tempIncome = incomeList.fold(
            0,
            (sum, incomeItem) => sum + (incomeItem.amount),
          );
          setState(() {
            income = tempIncome;
            isLoading = false;
          });
        });

    firestoreService
        .getExpensesByCategory(
          userId: user.uid,
          startDate: startOfMonth,
          endDate: endOfMonth,
        )
        .listen((categoryList) {
          setState(() {
            topExpenseCategories = categoryList.take(3).toList();
          });
        });

    firestoreService
        .getIncomesByCategory(
          userId: user.uid,
          startDate: startOfMonth,
          endDate: endOfMonth,
        )
        .listen((categoryList) {
          if (categoryList.isNotEmpty) {
            setState(() {
              topIncomeCategories = categoryList.take(3).toList();
            });
          }
        });
  }

  String formatCurrency(double value) {
    final format = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return format.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final balance = income - expenses;

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text(
      //     'Dasboard',
      //     style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
      //   ),
      // ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // Display the user's name at the top
                    FutureBuilder<String?>(
                      future: fetchUserName(),
                      builder: (context, snapshot) {
                        String name = snapshot.data ?? 'User';
                        return Row(
                          children: [
                            // Circle Avatar for User Profile
                            InkWell(
                              onTap: () => navController.changeIndex(3),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(Icons.person,size: 30),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Greeting Message
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Balance Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Balance Now',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatCurrency(balance),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                // Expenses Row
                                Expanded(
                                  child: Row(
                                    children: [
                                      Image.asset(
                                        "assets/icons/expenses.png",
                                        width: 40,
                                        height: 40,
                                      ),
                                      const SizedBox(width: 15),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Expenses',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                formatCurrency(expenses),
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Income Row
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 24.0),
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          "assets/icons/income.png",
                                          width: 40,
                                          height: 40,
                                        ),
                                        const SizedBox(width: 15),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Income',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  formatCurrency(income),
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const SizedBox(height: 16),
                    // Top Categories
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Top 3 Expense Categories (This Month)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: topExpenseCategories.length,
                      itemBuilder: (context, index) {
                        final category = topExpenseCategories[index];
                        return FutureBuilder<CategoryModel?>(
                          future: firestoreService.getExpenseCategoryById(
                            _auth.currentUser!.uid,
                            category['categoryId'],
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const ListTile(
                                leading: Icon(Icons.category),
                                title: Text('Loading...'),
                                trailing: Text('- Rp 0'),
                              );
                            }
                            if (!snapshot.hasData || snapshot.data == null) {
                              return const ListTile(
                                leading: Icon(Icons.category),
                                title: Text('Category not found'),
                                trailing: Text('- Rp 0'),
                              );
                            }
                            final categoryName = snapshot.data!.name;
                            final total = category['total'];
                            return ListTile(
                              leading: const Icon(Icons.category),
                              title: Text(categoryName),
                              trailing: Text(
                                '- ${formatCurrency(total)}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Top Categories
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Top 3 Income Categories (This Month)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: topIncomeCategories.length,
                      itemBuilder: (context, index) {
                        final category = topIncomeCategories[index];
                        return FutureBuilder<CategoryModel?>(
                          future: firestoreService.getIncomeCategoryById(
                            _auth.currentUser!.uid,
                            category['categoryId'],
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const ListTile(
                                leading: Icon(Icons.category),
                                title: Text('Loading...'),
                                trailing: Text('+ Rp 0'),
                              );
                            }
                            if (!snapshot.hasData || snapshot.data == null) {
                              return const ListTile(
                                leading: Icon(Icons.category),
                                title: Text('Category not found'),
                                trailing: Text('+ Rp 0'),
                              );
                            }
                            final categoryName = snapshot.data!.name;
                            final total = category['total'];
                            return ListTile(
                              leading: const Icon(Icons.category),
                              title: Text(categoryName),
                              trailing: Text(
                                '+ ${formatCurrency(total)}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
    );
  }
}
