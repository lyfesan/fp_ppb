import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:fp_ppb/services/firestore_service.dart';

class IncomeCategoryTab extends StatefulWidget {
  const IncomeCategoryTab({super.key});

  @override
  // The State class is made public to be accessible via the GlobalKey.
  State<IncomeCategoryTab> createState() => IncomeCategoryTabState();
}

class IncomeCategoryTabState extends State<IncomeCategoryTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _textController = TextEditingController();

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
            hintText: 'e.g., Salary',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _submitCategory(docID: docID);
            },
            child: Text(isUpdating ? 'Update' : 'Add'),
          ),
        ],
      ),
    ).then((_) => _textController.clear());
  }

  /// Handles the submission logic for adding or updating a category.
  void _submitCategory({String? docID}) {
    final name = _textController.text.trim();
    if (name.isEmpty) return; // Prevent empty category names

    final userId = FirebaseAuthService.currentUser!.uid;

    if (docID == null) {
      // Add new category
      _firestoreService.addCategoryIncome(userId, name);
    } else {
      // Update existing category
      _firestoreService.updateCategoryIncome(userId, docID, name);
    }

    Navigator.pop(context);
    _textController.clear();
  }

  /// Shows a confirmation dialog before deleting a category.
  void _confirmDelete(String docID) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this category? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final userId = FirebaseAuthService.currentUser!.uid;
              _firestoreService.deleteCategoryIncome(userId, docID);
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
      stream: _firestoreService.getCategoriesIncomeStream(FirebaseAuthService.currentUser!.uid),
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
              'No income categories found.\nTap the "+" button to add one.',
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
                    onPressed: () => _confirmDelete(docID),
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
