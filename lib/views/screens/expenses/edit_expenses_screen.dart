import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fp_ppb/models/currency_model.dart';
import 'package:fp_ppb/services/currency_exchange_service.dart';
import 'package:fp_ppb/models/category.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:intl/intl.dart';

import '../../../models/account.dart';
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
  String? _selectedAccountId;
  bool _isAddingNewCategory = false;
  late DateTime _selectedDate;

  final FirestoreService firestoreService = FirestoreService();
  final CurrencyExchangeService _currencyService = CurrencyExchangeService.instance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.expense.name);
    _selectedCategoryId = widget.expense.categoryId;
    _selectedAccountId = widget.expense.accountId;
    _selectedDate = widget.expense.date;

    // Convert the stored IDR amount to the active currency for initial display
    final initialDisplayAmount = widget.expense.amount * _currencyService.exchangeRateNotifier.value;
    _amountController = TextEditingController(text: _formatForDisplay(initialDisplayAmount));

    _amountController.addListener(() => setState(() {}));
  }

  String _formatForDisplay(double amount) {
    // Formatter for display, allows decimals for non-IDR currencies
    final format = NumberFormat("#,##0.##", "en_US");
    return format.format(amount);
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user logged in.");

      if (_isAddingNewCategory) {
        final newCategoryName = _newCategoryController.text.trim();
        if (newCategoryName.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a category name')));
          setState(() => _isSaving = false);
          return;
        }
        final newCategoryId = await firestoreService.addCategoryExpense(user.uid, newCategoryName);
        _selectedCategoryId = newCategoryId;
      }

      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
        setState(() => _isSaving = false);
        return;
      }

      // --- CONVERSION LOGIC ON SAVE ---
      final amountInActiveCurrency = double.tryParse(
          _amountController.text.replaceAll('.', '').replaceAll(',', '')
      ) ?? 0.0;
      final exchangeRate = _currencyService.exchangeRateNotifier.value;
      // Convert the input amount back to IDR for saving
      final amountInIdr = (exchangeRate > 0) ? amountInActiveCurrency / exchangeRate : 0.0;

      final updatedExpense = widget.expense.copyWith(
        name: _nameController.text.trim(),
        amount: amountInIdr, // Save the converted IDR value
        accountId: _selectedAccountId,
        categoryId: _selectedCategoryId,
        date: _selectedDate,
      );

      await firestoreService.updateExpense(expense: updatedExpense);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update expense: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  TextInputFormatter thousandsSeparatorInputFormatter() {
    final formatter = NumberFormat.decimalPattern('id'); // uses '.' for thousands
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text.replaceAll('.', '').replaceAll(',', '');
      if (text.isEmpty) return newValue.copyWith(text: '');

      final number = int.tryParse(text);
      if (number == null) return oldValue;

      final newText = formatter.format(number);
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    });
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  void dispose() {
    _amountController.removeListener(() {});
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Expense Name', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),

              // Amount Field with updated logic
              ValueListenableBuilder<Currency>(
                valueListenable: _currencyService.activeCurrencyNotifier,
                builder: (context, activeCurrency, child) {
                  return TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      border: const OutlineInputBorder(),
                      prefixText: '${activeCurrency.symbol} ',
                    ),
                    inputFormatters: [thousandsSeparatorInputFormatter()],
                    validator: (value) {
                      final clean = value?.replaceAll('.', '').replaceAll(',', '') ?? '';
                      if (clean.isEmpty || (double.tryParse(clean) ?? 0) <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Source Account
              StreamBuilder<QuerySnapshot>(
                stream: firestoreService.getFinanceAccountStream(FirebaseAuthService.currentUser!.uid),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError || snapshot.data!.docs.isEmpty) return const Text('No accounts found.');

                  final accounts = snapshot.data!.docs.map((doc) => AccountModel.fromFirestore(doc)).toList();
                  return DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    items: accounts.map((account) => DropdownMenuItem<String>(value: account.id, child: Text(account.name))).toList(),
                    onChanged: (value) => setState(() => _selectedAccountId = value),
                    decoration: const InputDecoration(labelText: 'Source Account', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Please select an account' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              _buildCategoryDropdown(),

              if (_isAddingNewCategory)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: TextFormField(
                    controller: _newCategoryController,
                    decoration: const InputDecoration(labelText: 'New Category Name', border: OutlineInputBorder()),
                    validator: (v) => _isAddingNewCategory && (v == null || v.trim().isEmpty) ? 'Please enter a category name' : null,
                  ),
                ),
              const SizedBox(height: 16),

              // Date picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Date: ${DateFormat('dd MMM y').format(_selectedDate)}', style: const TextStyle(fontSize: 16)),
                  TextButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today), label: const Text('Change')),
                ],
              ),
              const SizedBox(height: 24),

              // Buttons
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _isSaving ? null : _updateExpense,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Update Expense'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _isSaving ? null : _deleteExpense,
                child: _isSaving ? const SizedBox.shrink() : const Text('Delete Expense', style: TextStyle(color: Colors.white),),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getCategoriesExpenseStream(FirebaseAuthService.currentUser!.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || snapshot.data!.docs.isEmpty) return const Text('No categories found.');

        final categories = snapshot.data!.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
        if (!categories.any((c) => c.id == _selectedCategoryId)) _selectedCategoryId = null;

        List<DropdownMenuItem<String>> dropdownItems = categories.map((category) {
          return DropdownMenuItem<String>(value: category.id, child: Text(category.name));
        }).toList();

        dropdownItems.add(
          DropdownMenuItem(
            value: '--add-new-category--',
            child: Row(children: const [Icon(Icons.add, color: Colors.blueAccent), SizedBox(width: 8), Text('Add New Category', style: TextStyle(color: Colors.blueAccent))]),
          ),
        );

        return DropdownButtonFormField<String>(
          value: _selectedCategoryId,
          items: dropdownItems,
          onChanged: (value) {
            setState(() {
              if (value == '--add-new-category--') {
                _isAddingNewCategory = true;
                _selectedCategoryId = null;
              } else {
                _isAddingNewCategory = false;
                _selectedCategoryId = value;
              }
            });
          },
          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
          validator: (v) => !_isAddingNewCategory && (v == null || v.isEmpty) ? 'Please select a category' : null,
        );
      },
    );
  }

  Future<void> _deleteExpense() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await firestoreService.deleteExpense(expenseId: widget.expense.id, userId: widget.expense.userId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete expense: $e')));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }
}
