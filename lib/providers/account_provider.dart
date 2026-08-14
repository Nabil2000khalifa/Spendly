import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/account.dart';
import '../models/transfer.dart';

class AccountProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Account> _accounts = [];
  Map<int, double> _balances = {};
  Account? _defaultAccount;

  List<Account> get allAccounts => _accounts;

  List<Account> get activeAccounts =>
      _accounts.where((a) => a.isActive).toList();

  List<Account> get inactiveAccounts =>
      _accounts.where((a) => !a.isActive).toList();

  Account? get defaultAccount => _defaultAccount;

  Map<int, double> get balances => _balances;

  /// Combined total balance of all active accounts.
  double get totalBalance {
    double sum = 0.0;
    for (final acc in activeAccounts) {
      if (acc.id != null) {
        sum += _balances[acc.id!] ?? 0.0;
      }
    }
    return sum;
  }

  double getAccountBalance(int accountId) => _balances[accountId] ?? 0.0;
  double getBalance(int accountId) => getAccountBalance(accountId);

  Account? getAccountById(int? id) {
    if (id == null) return null;
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Init & Load ──────────────────────────────────────────────────────────

  Future<void> init() async {
    await loadAccounts();
  }

  Future<void> loadAccounts() async {
    _accounts = await _db.getAccounts(includeInactive: true);
    final map = <int, double>{};
    Account? defAcc;

    for (final acc in _accounts) {
      if (acc.id != null) {
        final bal = await _db.getAccountBalance(acc.id!);
        map[acc.id!] = bal;
      }
      if (acc.isDefault && acc.isActive) {
        defAcc = acc;
      }
    }

    // Fallback default account if none set or default is inactive
    if (defAcc == null && activeAccounts.isNotEmpty) {
      defAcc = activeAccounts.first;
    }

    _balances = map;
    _defaultAccount = defAcc;
    notifyListeners();
  }

  // ─── Account CRUD ──────────────────────────────────────────────────────────

  Future<int> addAccount(Account account) async {
    final id = await _db.insertAccount(account);
    await loadAccounts();
    return id;
  }

  Future<void> updateAccount(Account account) async {
    await _db.updateAccount(account);
    await loadAccounts();
  }

  Future<void> setDefaultAccount(int accountId) async {
    await _db.setDefaultAccount(accountId);
    await loadAccounts();
  }

  Future<void> deactivateAccount(int accountId) async {
    await _db.setAccountActive(accountId, false);
    await loadAccounts();
  }

  Future<void> reactivateAccount(int accountId) async {
    await _db.setAccountActive(accountId, true);
    await loadAccounts();
  }

  Future<bool> hasTransactions(int accountId) async {
    return await _db.hasAccountTransactions(accountId);
  }

  // ─── Transfer CRUD ─────────────────────────────────────────────────────────

  Future<void> addTransfer(AccountTransfer transfer) async {
    await _db.insertTransfer(transfer);
    await loadAccounts();
  }

  Future<void> deleteTransfer(int transferId) async {
    await _db.deleteTransfer(transferId);
    await loadAccounts();
  }

  Future<List<AccountTransfer>> getTransfersForAccount(int accountId) async {
    return await _db.getTransfers(accountId: accountId);
  }
}
