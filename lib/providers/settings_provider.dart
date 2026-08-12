import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyCurrency = 'currency';
  static const _keyCurrencySymbol = 'currency_symbol';

  String _currency = 'USD';
  String _currencySymbol = '\$';

  String get currency => _currency;
  String get currencySymbol => _currencySymbol;

  static const List<Map<String, String>> supportedCurrencies = [
    {'code': 'USD', 'symbol': '\$',  'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€',  'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£',  'name': 'British Pound'},
    {'code': 'INR', 'symbol': '₹',  'name': 'Indian Rupee'},
    {'code': 'PKR', 'symbol': '₨',  'name': 'Pakistani Rupee'},
    {'code': 'AED', 'symbol': 'د.إ','name': 'UAE Dirham'},
    {'code': 'SAR', 'symbol': '﷼',  'name': 'Saudi Riyal'},
    {'code': 'JPY', 'symbol': '¥',  'name': 'Japanese Yen'},
    {'code': 'CNY', 'symbol': '¥',  'name': 'Chinese Yuan'},
    {'code': 'CAD', 'symbol': 'C\$','name': 'Canadian Dollar'},
    {'code': 'AUD', 'symbol': 'A\$','name': 'Australian Dollar'},
    {'code': 'BDT', 'symbol': '৳',  'name': 'Bangladeshi Taka'},
    {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
    {'code': 'SGD', 'symbol': 'S\$','name': 'Singapore Dollar'},
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currency = prefs.getString(_keyCurrency) ?? 'USD';
    _currencySymbol = prefs.getString(_keyCurrencySymbol) ?? '\$';
    notifyListeners();
  }

  Future<void> setCurrency(String code, String symbol) async {
    _currency = code;
    _currencySymbol = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, code);
    await prefs.setString(_keyCurrencySymbol, symbol);
    notifyListeners();
  }

  String formatAmount(double amount) {
    if (amount >= 1000000) {
      return '$_currencySymbol${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$_currencySymbol${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$_currencySymbol${amount.toStringAsFixed(2)}';
  }

  String formatAmountFull(double amount) {
    return '$_currencySymbol${amount.toStringAsFixed(2)}';
  }
}
