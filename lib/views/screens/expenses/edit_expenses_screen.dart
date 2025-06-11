import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fp_ppb/models/category.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:fp_ppb/views/screens/category/category_expense_screen.dart';

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
  final _newCategoryController = TextEditingController();

  String? _selectedCategoryId;
  bool _isAddingNewCategory = false;
  late DateTime _selectedDate;

  final FirestoreService firestoreService = FirestoreService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.expense.name);
    // Format amount as string with dots:
    _amountController = TextEditingController(text: formatWithDots(widget.expense.amount.toInt().toString()));
    _selectedCategoryId = widget.expense.categoryId;
    _selectedDate = widget.expense.date;
  }

  String formatWithDots(String input) {
    // Remove non-digit chars (like existing dots)
    String digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');

    StringBuffer buffer = StringBuffer();
    int len = digitsOnly.length;

    for (int i = 0; i < len; i++) {
      buffer.write(digitsOnly[i]);

      int posFromRight = len - i - 1;
      if (posFromRight > 0 && posFromRight % 3 == 0) {
        buffer.write('.');
      }
    }

    return buffer.toString();
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user logged in.");

      // If adding new category inline, add it first
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

      final updatedExpense = widget.expense.copyWith(
        name: _nameController.text.trim(),
        amount: amount,
        categoryId: _selectedCategoryId,
        date: _selectedDate,
      );

      await firestoreService.updateExpense(expense: updatedExpense);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update expense: $e')),
      );
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
    _newCategoryController.dispose();
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
              // Name field
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

              // Amount field with formatting
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

              // Category dropdown with inline add new category
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
                        return const Text('No categories found.');
                      }

                      final categories = snapshot.data!.docs
                          .map((doc) => CategoryModel.fromFirestore(doc))
                          .toList();

                      // Reset category selection if current selection is deleted
                      final categoryIds = categories.map((c) => c.id).toList();
                      if (!categoryIds.contains(_selectedCategoryId)) {
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
                              _isAddingNewCategory = false;
                              _selectedCategoryId = value;
                              _newCategoryController.clear();
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_isAddingNewCategory) return null;
                          if (value == null || value.isEmpty) {
                            return 'Please select a category';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                ],
              ),

              // Inline new category input if adding new category
              if (_isAddingNewCategory)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'New Category Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _newCategoryController,
                      decoration: const InputDecoration(
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
                ),

              const SizedBox(height: 16),

              // Date picker
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
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Update Expense'),
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Expense'),
                      content: const Text(
                          'Are you sure you want to delete this expense?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    setState(() {
                      _isSaving = true;
                    });

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await firestoreService.deleteExpense(
                          expenseId: widget.expense.id,
                          userId: user.uid,
                        );
                        if (mounted) Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                              Text('Failed to delete expense: $e')),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isSaving = false;
                        });
                      }
                    }
                  }
                },
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Delete Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

