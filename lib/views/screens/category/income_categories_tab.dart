import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:fp_ppb/services/firestore_service.dart';

import 'category_form_screen.dart';

class IncomeCategoryTab extends StatefulWidget {
  const IncomeCategoryTab({super.key});

  @override
  // The State class is made public to be accessible via the GlobalKey.
  State<IncomeCategoryTab> createState() => IncomeCategoryTabState();
}

class IncomeCategoryTabState extends State<IncomeCategoryTab> {
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
              await _firestoreService.updateCategoryIncome(userId, docID!, name, icon);
            } else {
              await _firestoreService.addCategoryIncome(userId, name, icon);
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
      _firestoreService.addCategoryIncome(userId, name, _selectedIcon);
    } else {
      _firestoreService.updateCategoryIncome(userId, docID, name, _selectedIcon);
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
