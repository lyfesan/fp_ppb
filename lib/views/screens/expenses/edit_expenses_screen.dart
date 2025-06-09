import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fp_ppb/models/category.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:fp_ppb/views/screens/category_expense_screen.dart';

import '../../../models/expense.dart';
import '../../../services/firestore_service.dart';

class EditExpenseScreen extends StatefulWidget {
  final Expense expense;

  const EditExpenseScreen({super.key, required this.expense});

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;

  String? _selectedCategoryId;
  late DateTime _selectedDate;

  final FirestoreService firestoreService = FirestoreService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.expense.name);
    _amountController = TextEditingController(text: widget.expense.amount);
    _selectedCategoryId = widget.expense.categoryId;
    _selectedDate = widget.expense.date;
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedExpense = widget.expense.copyWith(
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text.trim()).toString(),
        categoryId: _selectedCategoryId,
        date: _selectedDate,
      );

      await firestoreService.updateExpense(expense: updatedExpense);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update expense: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
    // Hapus dispose untuk _categoryController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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

              StreamBuilder<QuerySnapshot>(
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
                    return const Text('No categories found.');
                  }

                  final categories =
                      snapshot.data!.docs.map((doc) {
                        return CategoryModel.fromFirestore(doc);
                      }).toList();

                  final categoryIds = categories.map((e) => e.id).toList();
                  if (!categoryIds.contains(_selectedCategoryId)) {
                    // Jika kategori lama sudah dihapus, reset pilihan
                    _selectedCategoryId = null;
                  }

                  List<DropdownMenuItem<String>> dropdownItems =
                      categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList();

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
                      if (value == '--add-new-category--') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoryExpenseScreen(),
                          ),
                        );
                        // Reset pilihan agar dropdown tidak menampilkan 'Add New Category'
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                  ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pick Date'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _updateExpense,
                child:
                    _isSaving
                        ? const CircularProgressIndicator()
                        : const Text('Update Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
