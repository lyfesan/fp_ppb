import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fp_ppb/services/firestore_service.dart';
import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';

class CategoryExpenseScreen extends StatefulWidget {
  const CategoryExpenseScreen({super.key});

  @override
  State<CategoryExpenseScreen> createState() => _CategoryExpenseScreenState();
}

class _CategoryExpenseScreenState extends State<CategoryExpenseScreen> {
  final FirestoreService firestoreService = FirestoreService();
  final TextEditingController textController = TextEditingController();

  void openCategoryBox({String? docID, String? existingText}) {
    textController.text = existingText ?? '';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(docID == null ? 'Add Category' : 'Update Category'),
            content: Form(
              child: TextFormField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter your category here',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  final text = textController.text.trim();
                  Navigator.pop(context);

                  if (docID == null) {
                    firestoreService.addCategoryExpense(
                      FirebaseAuthService.currentUser!.uid,
                      text,
                    );
                  } else {
                    firestoreService.updateCategoryExpense(
                      FirebaseAuthService.currentUser!.uid,
                      docID,
                      text,
                    );
                  }
                  textController.clear();
                },
                child: Text(docID == null ? 'Add' : 'Update'),
              ),
            ],
          ),
    ).then((_) {
      // Reset jika user tap di luar dialog
      textController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense Categories'),
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
        stream: firestoreService.getCategoriesExpenseStream(
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
                              .checkCategoryExpense(
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
                                                .deleteCategoryExpense(
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
