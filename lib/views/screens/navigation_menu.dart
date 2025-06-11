import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'expenses/expenses_screen.dart';
import 'category_expense_screen.dart';
import 'category_income_screen.dart';
import 'income/incomes_screen.dart';
import 'home_screen.dart';

class NavigationMenu extends StatelessWidget {
  NavigationMenu({super.key});
  final NavigationController navController = Get.find();

  final List<Widget> screens = const [
    HomeScreen(),
    ExpensesScreen(),
    // CategoryExpenseScreen(),
    IncomesScreen(),
    // Center(child: Text('Income')),
    // Center(child: Text('Settings')),
    CategoryIncomeScreen(),
    // CategoryExpenseScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        body: screens[navController.selectedIndex.value],
        bottomNavigationBar: NavigationBar(
          selectedIndex: navController.selectedIndex.value,
          onDestinationSelected: navController.changeIndex,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: "Home"),
            NavigationDestination(
              icon: Icon(Icons.speaker_notes_outlined),
              label: "Expenses",
            ),
            NavigationDestination(
              icon: Icon(Icons.sticky_note_2_outlined),
              label: "Income",
            ),
            NavigationDestination(icon: Icon(Icons.person), label: "Settings"),
          ],
        ),
      ),
    );
  }
}

class NavigationController extends GetxController {
  var selectedIndex = 0.obs;

  void changeIndex(int index) {
    selectedIndex.value = index;
  }
}
