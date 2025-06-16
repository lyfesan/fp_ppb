import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fp_ppb/models/currency_model.dart';
import '../core/constants/predefined_data.dart';

class CurrencyExchangeService {
  // --- Singleton Setup ---
  CurrencyExchangeService._internal();
  static final CurrencyExchangeService instance = CurrencyExchangeService._internal();

  // --- SharedPreferences Keys ---
  static const _codeKey = 'active_currency_code';
  static const _symbolKey = 'active_currency_symbol';
  static const _rateKey = 'active_currency_rate';

  // --- Reactive Notifier ---
  final ValueNotifier<Currency> activeCurrencyNotifier = ValueNotifier(
    const Currency(name: 'Indonesian Rupiah', code: 'IDR', symbol: 'Rp'),
  );

  final ValueNotifier<double> exchangeRateNotifier = ValueNotifier(1.0);

  Future<void> initialize() async {
    await _loadActiveCurrency();
    await fetchAndSetCurrency(activeCurrencyNotifier.value, forceUpdate: true);
  }

  // --- Main Logic ---
  Future<bool> fetchAndSetCurrency(Currency newCurrency, {bool forceUpdate = false}) async {
    if (newCurrency.code == activeCurrencyNotifier.value.code && !forceUpdate) {
      return true;
    }

    // List of URLs to try in order
    final List<String> urls = [
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/idr.json',
      'https://latest.currency-api.pages.dev/v1/currencies/idr.json', // Fallback URL
    ];

    for (final urlString in urls) {
      try {
        print("Attempting to fetch currency data from: $urlString");
        final url = Uri.parse(urlString);
        final response = await http.get(url).timeout(const Duration(seconds: 10)); // Added timeout

        if (response.statusCode == 200) {
          print("Successfully fetched data from: $urlString");
          final Map<String, dynamic> data = json.decode(response.body);
          final Map<String, dynamic> rates = data['idr'];

          final double rate = (rates[newCurrency.code.toLowerCase()] as num?)?.toDouble() ?? 1.0;

          // Update notifiers
          activeCurrencyNotifier.value = newCurrency;
          exchangeRateNotifier.value = rate;

          await _saveActiveCurrency(newCurrency, rate);
          return true; // Success, exit the function
        } else {
          print("Failed to fetch from $urlString. Status code: ${response.statusCode}");
          // Continue to the next URL in the list
        }
      } catch (e) {
        print("Error fetching currency data from $urlString: $e");
        // Continue to the next URL in the list
      }
    }

    // If the loop completes without returning true, all URLs have failed.
    print("All currency API URLs failed.");
    return false;
  }

  /// Saves the active currency details to SharedPreferences.
  Future<void> _saveActiveCurrency(Currency currency, double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeKey, currency.code);
    await prefs.setString(_symbolKey, currency.symbol);
    await prefs.setDouble(_rateKey, rate);
  }

  /// Loads the active currency from SharedPreferences on app start.
  Future<void> _loadActiveCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_codeKey);
    final symbol = prefs.getString(_symbolKey);
    final rate = prefs.getDouble(_rateKey);

    if (code != null && symbol != null && rate != null) {
      // Find the full Currency object from our predefined list
      final loadedCurrency = PredefinedData.currencies.firstWhere(
            (c) => c.code == code,
        orElse: () => const Currency(name: 'Indonesian Rupiah', code: 'IDR', symbol: 'Rp'), // Fallback
      );
      activeCurrencyNotifier.value = loadedCurrency;
      exchangeRateNotifier.value = rate;
    }
  }
}
