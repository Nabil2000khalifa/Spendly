import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';

class ExpenseProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Expense> _expenses = [];
  List<ExpenseCategory> _categories = [];
  List<Budget> _budgets = [];

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<Expense> get expenses => _expenses;
  List<ExpenseCategory> get categories => _categories;
  List<Budget> get budgets => _budgets;
  int get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;

  // ─── Summary Getters ───────────────────────────────────────────────────────

  double get totalExpenses => _expenses
      .where((e) => e.isExpense)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get totalIncome => _expenses
      .where((e) => e.isIncome)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get balance => totalIncome - totalExpenses;

  List<Expense> get recentExpenses => _expenses.take(30).toList();

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await loadCategories();
    await loadExpenses();
    await loadBudgets();
  }

  Future<void> loadExpenses() async {
    _expenses = await _db.getExpenses(
      month: _selectedMonth,
      year: _selectedYear,
    );
    notifyListeners();
  }

  Future<void> loadCategories() async {
    _categories = await _db.getCategories();
    notifyListeners();
  }

  Future<void> loadBudgets() async {
    _budgets = await _db.getBudgets(
      month: _selectedMonth,
      year: _selectedYear,
    );
    notifyListeners();
  }

  Future<void> setMonth(int month, int year) async {
    if (_selectedMonth == month && _selectedYear == year) return;
    _selectedMonth = month;
    _selectedYear = year;
    final results = await Future.wait([
      _db.getExpenses(month: _selectedMonth, year: _selectedYear),
      _db.getBudgets(month: _selectedMonth, year: _selectedYear),
    ]);
    _expenses = results[0] as List<Expense>;
    _budgets = results[1] as List<Budget>;
    notifyListeners();
  }

  // ─── Expense CRUD ──────────────────────────────────────────────────────────

  Future<void> addExpense(Expense expense) async {
    await _db.insertExpense(expense);
    await loadExpenses();
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    await _db.deleteExpense(id);
    await loadExpenses();
  }

  Future<void> deleteAllExpenses() async {
    await _db.deleteAllExpenses();
    await loadExpenses();
  }

  // ─── Category helpers ──────────────────────────────────────────────────────

  ExpenseCategory? getCategoryById(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Budget CRUD ───────────────────────────────────────────────────────────

  Future<void> setBudget(Budget budget) async {
    await _db.upsertBudget(budget);
    await loadBudgets();
  }

  Future<void> deleteBudget(int id) async {
    await _db.deleteBudget(id);
    await loadBudgets();
  }

  Budget? getBudgetForCategory(int categoryId) {
    try {
      return _budgets.firstWhere((b) => b.categoryId == categoryId);
    } catch (_) {
      return null;
    }
  }

  double getSpentForCategory(int categoryId) {
    return _expenses
        .where((e) => e.categoryId == categoryId && e.isExpense)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  // ─── Statistics ────────────────────────────────────────────────────────────

  Future<Map<int, double>> getCategoryBreakdown({int? accountId}) async {
    return await _db.getExpensesByCategory(_selectedMonth, _selectedYear, accountId: accountId);
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals({int? accountId}) async {
    return await _db.getMonthlyTotals(6, accountId: accountId);
  }

  // ─── Export ────────────────────────────────────────────────────────────────

  Future<List<Expense>> getAllExpensesForExport() async {
    return await _db.getExpenses();
  }
}
