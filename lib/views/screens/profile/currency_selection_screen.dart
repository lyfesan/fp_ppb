import 'package:flutter/material.dart';
import 'package:fp_ppb/core/constants/predefined_data.dart';
import 'package:fp_ppb/services/currency_exchange_service.dart';

import '../../../models/currency_model.dart';

class CurrencySelectionScreen extends StatefulWidget {
  const CurrencySelectionScreen({super.key});

  @override
  State<CurrencySelectionScreen> createState() => _CurrencySelectionScreenState();
}

class _CurrencySelectionScreenState extends State<CurrencySelectionScreen> {
  final CurrencyExchangeService _currencyService = CurrencyExchangeService.instance;
  bool _isLoading = false;

  Future<void> _onCurrencySelected(Currency selectedCurrency) async {
    setState(() => _isLoading = true);

    final success = await _currencyService.fetchAndSetCurrency(selectedCurrency);

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update currency. Please check your internet connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Currency'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Listens to changes in the active currency and rebuilds the list
          ValueListenableBuilder<Currency>(
            valueListenable: _currencyService.activeCurrencyNotifier,
            builder: (context, activeCurrency, child) {
              return ListView.separated(
                itemCount: PredefinedData.currencies.length,
                separatorBuilder: (context, index) => const Divider(height: 0, indent: 16),
                itemBuilder: (context, index) {
                  final currency = PredefinedData.currencies[index];
                  final bool isSelected = currency.code == activeCurrency.code;

                  return ListTile(
                    onTap: () => _onCurrencySelected(currency),
                    title: Text(currency.name),
                    subtitle: Text(currency.code),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                        : null,
                  );
                },
              );
            },
          ),
          // Shows a loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha:0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
