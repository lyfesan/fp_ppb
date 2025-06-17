import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/models/expense.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:fp_ppb/services/firestore_service.dart';

import 'category_form_screen.dart';

class ExpenseCategoryTab extends StatefulWidget {
  const ExpenseCategoryTab({super.key});

  @override
  // The State class is made public to be accessible via the GlobalKey.
  State<ExpenseCategoryTab> createState() => ExpenseCategoryTabState();
}

class ExpenseCategoryTabState extends State<ExpenseCategoryTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _textController = TextEditingController();
  String _selectedIcon = 'money.png';

  // List of available icons
  final List<String> _availableIcons = [
    'bills.png',
    'bonus.png',
    'chocolate.png',
    'duck.png',
    'education.png',
    'energy.png',
    'food.png',
    'gift.png',
    'handbody.png',
    'health.png',
    'iguana.png',
    'invest.png',
    'money.png',
    'pet_food.png',
    'pigeon.png',
    'popcorn.png',
    'sheep.png',
    'shirt.png',
    'shopping.png',
    'transportation.png',
    'water.png',
    'workout.png',
  ];

  /// Opens a dialog to either add a new category or update an existing one.
  void openAddOrUpdateScreen({String? docID, String? currentName, String? currentIcon}) {
    final isUpdating = docID != null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryFormScreen(
          initialName: currentName,
          initialIcon: currentIcon,
          isUpdate: isUpdating,
          onSubmit: (name, icon) async {
            final userId = FirebaseAuthService.currentUser!.uid;

            if (isUpdating) {
              await _firestoreService.updateCategoryExpense(userId, docID!, name, icon);
            } else {
              await _firestoreService.addCategoryExpense(userId, name, icon);
            }
          },
        ),
      ),
    );
  }


  /// Handles the submission logic for adding or updating a category.
  void _submitCategory({String? docID}) {
    final name = _textController.text.trim();
    if (name.isEmpty) return;

    final userId = FirebaseAuthService.currentUser!.uid;
    if (docID == null) {
      _firestoreService.addCategoryExpense(userId, name, _selectedIcon);
    } else {
      _firestoreService.updateCategoryExpense(userId, docID, name, _selectedIcon);
    }

    Navigator.pop(context);
    _textController.clear();
  }

  /// Handles the delete action by first checking for dependencies.
  Future<void> _handleDelete(String docID) async {
    final userId = FirebaseAuthService.currentUser!.uid;
    // Check if any expenses are using this category before deleting.
    final linkedExpenses = await _firestoreService.checkCategoryExpense(userId, docID);

    if (!mounted) return;

    if (linkedExpenses.isNotEmpty) {
      // If there are dependencies, show an informational dialog.
      _showCannotDeleteDialog(linkedExpenses);
    } else {
      // Otherwise, show the standard confirmation dialog.
      _showConfirmDeleteDialog(docID);
    }
  }

  /// Informs the user that the category cannot be deleted and shows why.
  void _showCannotDeleteDialog(List<Expense> expenses) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cannot Delete Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This category is in use by the following expenses and cannot be deleted:'),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: expenses.length,
                itemBuilder: (context, index) => Text('• ${expenses[index].name}'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog before permanently deleting a category.
  void _showConfirmDeleteDialog(String docID) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to permanently delete this category?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final userId = FirebaseAuthService.currentUser!.uid;
              _firestoreService.deleteCategoryExpense(userId, docID);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getCategoriesExpenseStream(FirebaseAuthService.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('An error occurred: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No expense categories found.\nTap the "+" button to add one.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final categories = snapshot.data!.docs;
        return ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final docID = category.id;
            final data = category.data() as Map<String, dynamic>;
            final categoryName = data['name'] as String? ?? 'No Name';

            return ListTile(
              leading: Image.asset(
                'assets/icons/${data['icon']}',
                width: 40,
                height: 40,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
              ),
              title: Text(categoryName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit), //color: Colors.blueAccent),
                    tooltip: 'Edit Category',
                    onPressed: () => openAddOrUpdateScreen(
                      docID: docID,
                      currentName: categoryName,
                      currentIcon: data['icon'],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Delete Category',
                    onPressed: () => _handleDelete(docID),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
