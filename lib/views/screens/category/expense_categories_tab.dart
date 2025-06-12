import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/models/expense.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:fp_ppb/services/firestore_service.dart';

class ExpenseCategoryTab extends StatefulWidget {
  const ExpenseCategoryTab({super.key});

  @override
  // The State class is made public to be accessible via the GlobalKey.
  State<ExpenseCategoryTab> createState() => ExpenseCategoryTabState();
}

class ExpenseCategoryTabState extends State<ExpenseCategoryTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _textController = TextEditingController();

  /// Opens a dialog to either add a new category or update an existing one.
  void openAddOrUpdateDialog({String? docID, String? currentName}) {
    _textController.text = currentName ?? '';
    final isUpdating = docID != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUpdating ? 'Update Category' : 'Add New Category'),
        content: TextFormField(
          controller: _textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Groceries',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => _submitCategory(docID: docID),
            child: Text(isUpdating ? 'Update' : 'Add'),
          ),
        ],
      ),
    ).then((_) => _textController.clear());
  }

  /// Handles the submission logic for adding or updating a category.
  void _submitCategory({String? docID}) {
    final name = _textController.text.trim();
    if (name.isEmpty) return;

    final userId = FirebaseAuthService.currentUser!.uid;
    if (docID == null) {
      _firestoreService.addCategoryExpense(userId, name);
    } else {
      _firestoreService.updateCategoryExpense(userId, docID, name);
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
              leading: const Icon(Icons.chevron_right),
              title: Text(categoryName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit), //color: Colors.blueAccent),
                    tooltip: 'Edit Category',
                    onPressed: () => openAddOrUpdateDialog(docID: docID, currentName: categoryName),
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
