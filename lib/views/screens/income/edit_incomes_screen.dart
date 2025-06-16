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
import '../../../models/income.dart';
import '../../../services/firestore_service.dart';

class EditIncomeScreen extends StatefulWidget {
  final Income incomeData;

  const EditIncomeScreen({super.key, required this.incomeData});

  @override
  State<EditIncomeScreen> createState() => _EditIncomeScreenState();
}

class _EditIncomeScreenState extends State<EditIncomeScreen> {
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.incomeData.name);
    _selectedCategoryId = widget.incomeData.categoryId;
    _selectedAccountId = widget.incomeData.accountId;
    _selectedDate = widget.incomeData.date;

    // Convert the stored IDR amount to the active currency for initial display
    final initialDisplayAmount = widget.incomeData.amount * _currencyService.exchangeRateNotifier.value;
    _amountController = TextEditingController(text: _formatForDisplay(initialDisplayAmount));

    _amountController.addListener(() => setState(() {}));
  }

  String _formatForDisplay(double amount) {
    // Formatter for display, allows decimals for non-IDR currencies
    final format = NumberFormat("#,##0.##", "en_US");
    return format.format(amount);
  }

  Future<void> _updateIncome() async {
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
        final newCategoryId = await firestoreService.addCategoryIncome(user.uid, newCategoryName, _selectedIcon!,);
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

      final updatedIncome = widget.incomeData.copyWith(
        name: _nameController.text.trim(),
        amount: amountInIdr, // Save the converted IDR value
        accountId: _selectedAccountId,
        categoryId: _selectedCategoryId,
        date: _selectedDate,
      );

      await firestoreService.updateIncome(incomeData: updatedIncome);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update income: $e')));
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
      appBar: AppBar(title: const Text('Edit Income')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Income Name', border: OutlineInputBorder()),
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
                    decoration: const InputDecoration(labelText: 'Destination Account', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Please select an account' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Category dropdown
              _buildCategoryDropdown(),

              if (_isAddingNewCategory) ...[
                TextFormField(
                  controller: _newCategoryController,
                  decoration: const InputDecoration(labelText: 'New Category Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedIcon,
                  decoration: const InputDecoration(labelText: 'Select Icon', border: OutlineInputBorder()),
                  items: _iconOptions.map((iconName) {
                    return DropdownMenuItem(
                      value: iconName,
                      child: Row(
                        children: [
                          Image.asset('assets/icons/$iconName', width: 24, height: 24),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedIcon = val),
                  validator: (v) => v == null ? 'Please select an icon' : null,
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

              // Buttons
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _isSaving ? null : _updateIncome,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Update Income'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _isSaving ? null : _deleteIncome,
                child: _isSaving ? const SizedBox.shrink() : Text('Delete Income', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.getCategoriesIncomeStream(FirebaseAuthService.currentUser!.uid),
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

  Future<void> _deleteIncome() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Income'),
        content: const Text('Are you sure you want to delete this income?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await firestoreService.deleteIncome(incomeId: widget.incomeData.id, userId: widget.incomeData.userId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete income: $e')));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }
}
