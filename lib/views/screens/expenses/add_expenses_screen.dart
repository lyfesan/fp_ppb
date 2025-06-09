import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:fp_ppb/views/screens/category_expense_screen.dart';

import '../../../models/expense.dart';
import '../../../models/category.dart';
import '../../../services/firestore_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();

  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  final FirestoreService firestoreService = FirestoreService();

  bool _isSaving = false;

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user logged in.");

      final newExpense = Expense(
        id: '', // Firestore will auto-generate ID
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text.trim()).toString(),
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        userId: user.uid,
      );

      // Pass both expense and user as required by updated addExpense
      await firestoreService.addExpense(expense: newExpense, user: user);

      if (mounted) {
        Navigator.pop(context); // Go back after successful save
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save expense: $e');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save expense: $e')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Expense Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Expense Name',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // category dropdown
              StreamBuilder<QuerySnapshot>(
                // Asumsi: setiap user punya koleksi 'categories' sendiri.
                // Sesuaikan path ini jika struktur Anda berbeda.
                stream: firestoreService.getCategoriesExpenseStream(
                  FirebaseAuthService.currentUser!.uid,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Text('Error loading categories');
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text(
                      'No categories found. Please add one first.',
                    );
                  }

                  // Ubah data snapshot menjadi list model
                  final categories =
                      snapshot.data!.docs.map((doc) {
                        // Anda perlu membuat factory constructor di CategoryModel
                        return CategoryModel.fromFirestore(doc);
                      }).toList();

                  // 1. Buat daftar item dropdown secara manual
                  List<DropdownMenuItem<String>> dropdownItems =
                      categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList();

                  // 2. Tambahkan item spesial "Add New Category" di akhir daftar
                  dropdownItems.add(
                    DropdownMenuItem(
                      value:
                          '--add-new-category--', // Nilai unik sebagai penanda
                      child: Row(
                        children: [
                          const Icon(Icons.add, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Add New Category',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    items:
                        dropdownItems, // Gunakan daftar yang sudah dimodifikasi
                    onChanged: (value) {
                      // 3. Tambahkan logika untuk menangani item spesial
                      if (value == '--add-new-category--') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoryExpenseScreen(),
                          ),
                        );
                        setState(() {
                          _selectedCategoryId = null;
                        });
                      } else {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    validator:
                        (value) =>
                            value == null ? 'Please select a category' : null,
                  );
                },
              ),
              // Date picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pick Date'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveExpense,
                child:
                    _isSaving
                        ? const CircularProgressIndicator()
                        : const Text('Save Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
