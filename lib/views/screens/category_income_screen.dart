import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fp_ppb/services/firestore_service.dart';
import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';

class CategoryIncomeScreen extends StatefulWidget {
  const CategoryIncomeScreen({super.key});

  @override
  State<CategoryIncomeScreen> createState() => _CategoryIncomeScreenState();
}

class _CategoryIncomeScreenState extends State<CategoryIncomeScreen> {
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
                    firestoreService.addCategoryIncome(
                      FirebaseAuthService.currentUser!.uid,
                      text,
                    );
                  } else {
                    firestoreService.updateCategoryIncome(
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
                        onPressed:
                            () => firestoreService.deleteCategoryIncome(
                              FirebaseAuthService.currentUser!.uid,
                              docID,
                            ),
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
