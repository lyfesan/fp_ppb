import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _newCategoryController = TextEditingController();

  String? _selectedCategoryId;
  bool _isAddingNewCategory = false;
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

      // If user is adding a new category inline, add it first
      if (_isAddingNewCategory) {
        final newCategoryName = _newCategoryController.text.trim();
        if (newCategoryName.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a category name')),
          );
          setState(() {
            _isSaving = false;
          });
          return;
        }

        // Add new category and get the ID
        final newCategoryId = await firestoreService.addCategoryExpense(
          user.uid,
          newCategoryName,
        );

        _selectedCategoryId = newCategoryId;
        _isAddingNewCategory = false;
        _newCategoryController.clear();
      }

      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final cleanedAmount = _amountController.text.replaceAll('.', '').trim();
      final amount = double.parse(cleanedAmount);

      final newExpense = Expense(
        id: '', // Firestore will auto-generate ID
        name: _nameController.text.trim(),
        amount: amount,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        userId: user.uid,
      );

      await firestoreService.addExpense(expense: newExpense, user: user);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save expense: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save expense: $e')),
      );
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

  String formatWithDots(String input) {
    // Remove non-digit chars (like existing dots)
    String digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');

    StringBuffer buffer = StringBuffer();
    int len = digitsOnly.length;

    for (int i = 0; i < len; i++) {
      buffer.write(digitsOnly[i]);

      // Add dot if this is not the last digit and position from right is multiple of 3
      int posFromRight = len - i - 1;
      if (posFromRight > 0 && posFromRight % 3 == 0) {
        buffer.write('.');
      }
    }

    return buffer.toString();
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expense Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Enter a name' : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixText: 'Rp ',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      final cleaned = value?.replaceAll('.', '') ?? '';
                      final parsed = double.tryParse(cleaned);
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final formatted = formatWithDots(value);
                      if (formatted != value) {
                        _amountController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Category dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                        return const Text(
                          'No categories found. Please add one first.',
                        );
                      }

                      final categories = snapshot.data!.docs
                          .map((doc) => CategoryModel.fromFirestore(doc))
                          .toList();

                      final dropdownItems = categories
                          .map(
                            (category) => DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                          .toList();

                      dropdownItems.add(
                        DropdownMenuItem(
                          value: '--add-new-category--',
                          child: Row(
                            children: const [
                              Icon(Icons.add, color: Colors.blueAccent),
                              SizedBox(width: 8),
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
                        items: dropdownItems,
                        onChanged: (value) {
                          if (value == '--add-new-category--') {
                            setState(() {
                              _isAddingNewCategory = true;
                              _selectedCategoryId = null;
                            });
                          } else {
                            setState(() {
                              _selectedCategoryId = value;
                              _isAddingNewCategory = false;
                              _newCategoryController.clear();
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_isAddingNewCategory) return null; // skip validation if adding new category
                          if (value == null || value.isEmpty) return 'Please select a category';
                          return null;
                        },
                      );
                    },
                  ),
                ],
              ),

              // Inline add new category field
              if (_isAddingNewCategory) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newCategoryController,
                  decoration: const InputDecoration(
                    labelText: 'New Category Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_isAddingNewCategory &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please enter a category name';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 16),

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
                child: _isSaving
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