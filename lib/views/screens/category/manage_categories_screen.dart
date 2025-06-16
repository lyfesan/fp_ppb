import 'package:flutter/material.dart';
import 'expense_categories_tab.dart';
import 'income_categories_tab.dart';
//import 'income_category_tab.dart';
//import 'expense_category_tab.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // GlobalKeys are used to call methods on the child widgets' states.
  final GlobalKey<IncomeCategoryTabState> _incomeTabKey = GlobalKey<IncomeCategoryTabState>();
  final GlobalKey<ExpenseCategoryTabState> _expenseTabKey = GlobalKey<ExpenseCategoryTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  void _handleAddButtonPressed() {
    // _tabController.index == 0 corresponds to the "Income" tab.
    if (_tabController.index == 0) {
      _incomeTabKey.currentState?.openAddOrUpdateDialog();
    }
    // _tabController.index == 1 corresponds to the "Expense" tab.
    else {
      _expenseTabKey.currentState?.openAddOrUpdateDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        centerTitle: true,
        // The TabBar is placed in the `bottom` property of the AppBar.
        bottom: TabBar(
          controller: _tabController,
          //indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          tabs: const [
            Tab(icon: Icon(Icons.arrow_circle_down_outlined), text: 'Income'),
            Tab(icon: Icon(Icons.arrow_circle_up_outlined), text: 'Expense'),
          ],
        ),
      ),
      // The TabBarView displays the content of the selected tab.
      body: TabBarView(
        controller: _tabController,
        children: [
          // Each tab's content is a separate widget, identified by its key.
          IncomeCategoryTab(key: _incomeTabKey),
          ExpenseCategoryTab(key: _expenseTabKey),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        onPressed: _handleAddButtonPressed,
        tooltip: 'Add New Category',
        child: const Icon(Icons.add),
      ),
    );
  }
}
