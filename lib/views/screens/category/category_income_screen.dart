import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fp_ppb/services/firestore_service.dart';
import 'package:flutter/material.dart';
import '../../../services/firebase_auth_service.dart';
import 'category_form_screen.dart';

class CategoryIncomeScreen extends StatefulWidget {
  const CategoryIncomeScreen({super.key});

  @override
  State<CategoryIncomeScreen> createState() => _CategoryIncomeScreenState();
}

class _CategoryIncomeScreenState extends State<CategoryIncomeScreen> {
  final FirestoreService firestoreService = FirestoreService();
  final TextEditingController textController = TextEditingController();

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

  void openCategoryBox({String? docID, String? existingText, String? existingIcon}) {
    final isUpdating = docID != null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryFormScreen(
          initialName: existingText,
          initialIcon: existingIcon,
          isUpdate: isUpdating,
          onSubmit: (name, icon) async {
            final userId = FirebaseAuthService.currentUser!.uid;

            if (isUpdating) {
              await firestoreService.updateCategoryIncome(userId, docID!, name, icon);
            } else {
              await firestoreService.addCategoryIncome(userId, name, icon);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Income Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuthService.signOut();
              // AuthGate will handle navigation to LoginScreen
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => openCategoryBox(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getCategoriesIncomeStream(
          FirebaseAuthService.currentUser!.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final categoriesList = snapshot.data!.docs;

            return ListView.builder(
              itemCount: categoriesList.length,
              itemBuilder: (context, index) {
                final DocumentSnapshot document = categoriesList[index];
                final String docID = document.id;
                final data = document.data() as Map<String, dynamic>;
                final String categoryText = data['name'] as String? ?? '';

                return ListTile(
                  title: Text(categoryText),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed:
                            () => openCategoryBox(
                              docID: docID,
                              existingText: categoryText,
                            ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () async {
                          final expenses = await firestoreService
                              .checkCategoryIncome(
                                FirebaseAuthService.currentUser!.uid,
                                docID,
                              );

                          if (expenses.isNotEmpty) {
                            // Show a dialog to inform the user that the category cannot be deleted
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: Text(
                                      'Cannot Delete Category',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'The following expenses are linked to this category:',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        SizedBox(height: 8),
                                        SizedBox(
                                          height:
                                              200, // Adjust the height as needed
                                          width:
                                              300, // Adjust the width as needed
                                          child: ListView.builder(
                                            itemCount: expenses.length,
                                            itemBuilder: (context, index) {
                                              final expense = expenses[index];
                                              return Text(
                                                '${index + 1}. ${expense.name}',
                                                style: TextStyle(fontSize: 14),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('OK'),
                                      ),
                                    ],
                                  ),
                            );
                          } else {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: Text('Confirm Delete'),
                                    content: Text(
                                      'Are you sure you want to delete this category?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(
                                            context,
                                          ); // Close the confirmation dialog
                                          try {
                                            await firestoreService
                                                .deleteCategoryIncome(
                                                  FirebaseAuthService
                                                      .currentUser!
                                                      .uid,
                                                  docID,
                                                );
                                            // Category deleted successfully
                                            // Show a success message
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Category deleted successfully!',
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            // Handle other potential errors
                                            print(
                                              'Error deleting category: $e',
                                            );
                                          }
                                        },
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return Center(child: Text("No Categories..."));
          }
        },
      ),
    );
  }
}
