import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fp_ppb/models/currency_model.dart';
import 'package:fp_ppb/services/currency_exchange_service.dart';
import 'package:fp_ppb/services/firebase_auth_service.dart';
import 'package:intl/intl.dart';

import '../../../models/account.dart';
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
  String? _selectedAccountId;
  bool _isAddingNewCategory = false;
  DateTime _selectedDate = DateTime.now();
  final FirestoreService firestoreService = FirestoreService();
  final CurrencyExchangeService _currencyService = CurrencyExchangeService.instance;

  bool _isSaving = false;

  String? _selectedIcon;

  final List<String> _iconOptions = [
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


  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No user logged in.");

      if (_isAddingNewCategory) {
        final newCategoryName = _newCategoryController.text.trim();
        if (newCategoryName.isEmpty || _selectedIcon == null) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter a category name and select an icon')));
          setState(() => _isSaving = false);
          return;
        }

        final newCategoryId = await firestoreService.addCategoryExpense(
          user.uid,
          newCategoryName,
          _selectedIcon!, // Add this
        );
        _selectedCategoryId = newCategoryId;
      }

      if (_selectedCategoryId == null || _selectedAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an account and a category')));
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

      final newExpense = Expense(
        id: '', // Firestore will auto-generate ID
        name: _nameController.text.trim(),
        amount: amountInIdr, // Save the converted IDR value
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        userId: user.uid,
      );

      await firestoreService.addExpense(expense: newExpense, user: user);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save expense: $e')));
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
    _nameController.dispose();
    _amountController.dispose();
    _newCategoryController.dispose();
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
                decoration: const InputDecoration(labelText: 'Expense Name', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),

              // Amount Field
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

              // Account dropdown
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

              // Category dropdown
              _buildCategoryDropdown(),

              if (_isAddingNewCategory) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newCategoryController,
                  decoration: const InputDecoration(labelText: 'New Category Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Choose an icon:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150, // Adjust height to your design
                  child: GridView.builder(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: _iconOptions.length,
                    itemBuilder: (context, index) {
                      final iconName = _iconOptions[index];
                      final isSelected = iconName == _selectedIcon;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = iconName),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                          ),
                          child: Image.asset('assets/icons/$iconName', width: 40, height: 40),
                        ),
                      );
                    },
                  ),
                ),
              ],
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

              // Submit button
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _isSaving ? null : _saveExpense,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Expense'),
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
}
