import '../../models/currency_model.dart';

class PredefinedData {
  static const List<Map<String, String>> incomeCategories = [
    {"name": "Salary", "icon": "money.png"},
    {"name": "Investment", "icon": "money.png"},
    {"name": "Gift", "icon": "gift.png"},
    {"name": "Bonus", "icon": "bonus.png"},
    {"name": "Other", "icon": "duck.png"},
  ];

  static const List<Map<String, String>> expenseCategories = [
    {"name": "Food and Drink", "icon": "food.png"},
    {"name": "Transportation", "icon": "shopping.png"},
    {"name": "Bills and Utility", "icon": "bills.png"},
    {"name": "Entertainment", "icon": "popcorn.png"},
    {"name": "Other", "icon": "duck.png"},
  ];

  static final List<String> financeAccount = [
    "General",
  ];

  static final List<Currency> currencies = [
    const Currency(name: 'Indonesian Rupiah', code: 'IDR', symbol: 'Rp'),
    const Currency(name: 'US Dollar', code: 'USD', symbol: '\$'),
    const Currency(name: 'Saudi Riyal', code: 'SAR', symbol: 'SR'),
    const Currency(name: 'Singapore Dollar', code: 'SGD', symbol: 'S\$'),
    const Currency(name: 'Malaysian Ringgit', code: 'MYR', symbol: 'RM'),
    const Currency(name: 'Japanese Yen', code: 'JPY', symbol: '¥'),
    const Currency(name: 'Australian Dollar', code: 'AUD', symbol: 'A\$'),
    const Currency(name: 'Euro', code: 'EUR', symbol: '€'),
    const Currency(name: 'South Korean Won', code: 'KRW', symbol: '₩'),
    const Currency(name: 'Thai Baht', code: 'THB', symbol: '฿'),
    const Currency(name: 'British Pound', code: 'GBP', symbol: '£'),
    const Currency(name: 'Chinese Yuan', code: 'CNY', symbol: '¥'),
    const Currency(name: 'Hong Kong Dollar', code: 'HKD', symbol: 'HK\$'),
  ];
}