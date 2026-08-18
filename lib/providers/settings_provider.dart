import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyCurrency = 'currency';
  static const _keyCurrencySymbol = 'currency_symbol';

  // Default to INR — users can change in Settings
  String _currency = 'INR';
  String _currencySymbol = '₹';

  String get currency => _currency;
  String get currencySymbol => _currencySymbol;

  static const List<Map<String, String>> supportedCurrencies = [
    {'code': 'INR', 'symbol': '₹',  'name': 'Indian Rupee'},
    {'code': 'USD', 'symbol': '\$',  'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€',  'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£',  'name': 'British Pound'},
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

  /// Returns the currency symbol for a given currency code.
  /// Falls back to the code itself if not found.
  static String symbolForCurrency(String code) {
    if (code.isEmpty) return '';
    final found = supportedCurrencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => {'symbol': code},
    );
    return found['symbol'] ?? code;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currency = prefs.getString(_keyCurrency) ?? 'INR';
    _currencySymbol = prefs.getString(_keyCurrencySymbol) ?? '₹';
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

  /// Format amount using the global settings currency symbol.
  String formatAmount(double amount) {
    return _formatWithSymbol(amount, _currencySymbol, abbreviate: true);
  }

  /// Format amount using the global settings currency symbol (full precision).
  String formatAmountFull(double amount) {
    return _formatWithSymbol(amount, _currencySymbol, abbreviate: false);
  }

  /// Format amount using a specific currency code's symbol.
  String formatAmountForCurrency(double amount, String currencyCode) {
    final symbol = symbolForCurrency(currencyCode);
    return _formatWithSymbol(amount, symbol, abbreviate: true);
  }

  /// Format amount using a specific currency code's symbol (full precision).
  String formatAmountFullForCurrency(double amount, String currencyCode) {
    final symbol = symbolForCurrency(currencyCode);
    return _formatWithSymbol(amount, symbol, abbreviate: false);
  }

  String _formatWithSymbol(double amount, String symbol, {required bool abbreviate}) {
    if (abbreviate) {
      if (amount.abs() >= 1000000) {
        return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
      } else if (amount.abs() >= 1000) {
        return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
      }
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }
}
