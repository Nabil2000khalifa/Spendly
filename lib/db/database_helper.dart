import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/person.dart';
import '../models/loan.dart';
import '../models/loan_ledger_entry.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expense_manager.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ─── Schema Creation (fresh install) ─────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await _createExpenseTables(db);
    await _createLoanTables(db);
  }

  // ─── Migration (existing install v1 → v2) ─────────────────────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createLoanTables(db);
    }
  }

  // ─── Expense Tables (unchanged from v1) ───────────────────────────────────

  Future<void> _createExpenseTables(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        type TEXT NOT NULL DEFAULT 'expense',
        currency TEXT NOT NULL DEFAULT 'USD',
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        UNIQUE(category_id, month, year),
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    for (final cat in defaultCategories) {
      await db.insert('categories', cat.toMap()..remove('id'));
    }
  }

  // ─── Loan Tables (v2) ─────────────────────────────────────────────────────

  Future<void> _createLoanTables(Database db) async {
    await db.execute('''
      CREATE TABLE persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        principal_paise INTEGER NOT NULL,
        interest_enabled INTEGER NOT NULL DEFAULT 0,
        interest_type TEXT NOT NULL DEFAULT 'percentage',
        interest_rate REAL NOT NULL DEFAULT 0,
        interest_period TEXT NOT NULL DEFAULT 'one_time',
        start_date TEXT NOT NULL,
        due_date TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (person_id) REFERENCES persons(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE loan_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER NOT NULL,
        entry_type TEXT NOT NULL,
        amount_paise INTEGER NOT NULL,
        description TEXT NOT NULL,
        payment_method TEXT,
        entry_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (loan_id) REFERENCES loans(id)
      )
    ''');
  }

  // ─── Categories ───────────────────────────────────────────────────────────

  Future<List<ExpenseCategory>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'name ASC');
    return maps.map(ExpenseCategory.fromMap).toList();
  }

  Future<int> insertCategory(ExpenseCategory category) async {
    final db = await database;
    return await db.insert('categories', category.toMap()..remove('id'));
  }

  Future<int> updateCategory(ExpenseCategory category) async {
    final db = await database;
    return await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Expenses ─────────────────────────────────────────────────────────────

  Future<List<Expense>> getExpenses({int? month, int? year}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;

    if (month != null && year != null) {
      final start = DateTime(year, month, 1).toIso8601String();
      final end = DateTime(year, month + 1, 1).toIso8601String();
      maps = await db.query(
        'expenses',
        where: 'date >= ? AND date < ?',
        whereArgs: [start, end],
        orderBy: 'date DESC',
      );
    } else {
      maps = await db.query('expenses', orderBy: 'date DESC');
    }

    return maps.map(Expense.fromMap).toList();
  }

  Future<List<Expense>> getExpensesByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map(Expense.fromMap).toList();
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap()..remove('id'));
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update('expenses', expense.toMap(),
        where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllExpenses() async {
    final db = await database;
    await db.delete('expenses');
  }

  // ─── Budgets ──────────────────────────────────────────────────────────────

  Future<List<Budget>> getBudgets({required int month, required int year}) async {
    final db = await database;
    final maps = await db.query(
      'budgets',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
    );
    return maps.map(Budget.fromMap).toList();
  }

  Future<int> upsertBudget(Budget budget) async {
    final db = await database;
    return await db.insert(
      'budgets',
      budget.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteBudget(int id) async {
    final db = await database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Statistics ───────────────────────────────────────────────────────────

  Future<Map<int, double>> getExpensesByCategory(int month, int year) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();

    final result = await db.rawQuery('''
      SELECT category_id, SUM(amount) as total
      FROM expenses
      WHERE date >= ? AND date < ? AND type = 'expense'
      GROUP BY category_id
    ''', [start, end]);

    return {
      for (final row in result)
        (row['category_id'] as int): (row['total'] as num).toDouble()
    };
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals(int months) async {
    final db = await database;
    final now = DateTime.now();
    final results = <Map<String, dynamic>>[];

    for (int i = months - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final start = DateTime(date.year, date.month, 1).toIso8601String();
      final end = DateTime(date.year, date.month + 1, 1).toIso8601String();

      final expenseRow = await db.rawQuery('''
        SELECT SUM(amount) as total FROM expenses
        WHERE date >= ? AND date < ? AND type = 'expense'
      ''', [start, end]);

      final incomeRow = await db.rawQuery('''
        SELECT SUM(amount) as total FROM expenses
        WHERE date >= ? AND date < ? AND type = 'income'
      ''', [start, end]);

      results.add({
        'month': date.month,
        'year': date.year,
        'expense': (expenseRow.first['total'] as num?)?.toDouble() ?? 0.0,
        'income': (incomeRow.first['total'] as num?)?.toDouble() ?? 0.0,
      });
    }

    return results;
  }

  // ─── Persons ──────────────────────────────────────────────────────────────

  Future<List<Person>> getPersons() async {
    final db = await database;
    final maps = await db.query('persons', orderBy: 'name ASC');
    return maps.map(Person.fromMap).toList();
  }

  Future<Person?> getPerson(int id) async {
    final db = await database;
    final maps =
        await db.query('persons', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Person.fromMap(maps.first);
  }

  Future<int> insertPerson(Person person) async {
    final db = await database;
    return await db.insert('persons', person.toMap()..remove('id'));
  }

  Future<int> updatePerson(Person person) async {
    final db = await database;
    return await db.update('persons', person.toMap(),
        where: 'id = ?', whereArgs: [person.id]);
  }

  Future<int> deletePerson(int id) async {
    final db = await database;
    return await db.delete('persons', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Loans ────────────────────────────────────────────────────────────────

  Future<List<Loan>> getLoans() async {
    final db = await database;
    final maps = await db.query('loans', orderBy: 'created_at DESC');
    return maps.map(Loan.fromMap).toList();
  }

  Future<List<Loan>> getLoansByPerson(int personId) async {
    final db = await database;
    final maps = await db.query('loans',
        where: 'person_id = ?',
        whereArgs: [personId],
        orderBy: 'created_at DESC');
    return maps.map(Loan.fromMap).toList();
  }

  Future<Loan?> getLoan(int id) async {
    final db = await database;
    final maps =
        await db.query('loans', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Loan.fromMap(maps.first);
  }

  Future<int> insertLoan(Loan loan) async {
    final db = await database;
    return await db.insert('loans', loan.toMap()..remove('id'));
  }

  Future<int> updateLoan(Loan loan) async {
    final db = await database;
    return await db.update('loans', loan.toMap(),
        where: 'id = ?', whereArgs: [loan.id]);
  }

  Future<int> updateLoanStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      'loans',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Loan Ledger ──────────────────────────────────────────────────────────

  Future<List<LoanLedgerEntry>> getLedgerForLoan(int loanId) async {
    final db = await database;
    final maps = await db.query(
      'loan_ledger',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'entry_date ASC, created_at ASC',
    );
    return maps.map(LoanLedgerEntry.fromMap).toList();
  }

  Future<int> insertLedgerEntry(LoanLedgerEntry entry) async {
    final db = await database;
    return await db.insert('loan_ledger', entry.toMap()..remove('id'));
  }

  Future<int> deleteLedgerEntry(int id) async {
    final db = await database;
    return await db
        .delete('loan_ledger', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes all ledger entries for a loan (only used for full loan deletion)
  Future<void> deleteLedgerForLoan(int loanId) async {
    final db = await database;
    await db.delete('loan_ledger',
        where: 'loan_id = ?', whereArgs: [loanId]);
  }

  // ─── Loan Reports ─────────────────────────────────────────────────────────

  /// Returns all loan ledger entries for export
  Future<List<Map<String, dynamic>>> getAllLoanDataForExport() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        p.name as person_name,
        l.type as loan_type,
        l.principal_paise,
        l.status,
        l.start_date,
        l.due_date,
        ll.entry_type,
        ll.amount_paise,
        ll.description,
        ll.payment_method,
        ll.entry_date
      FROM loans l
      JOIN persons p ON l.person_id = p.id
      JOIN loan_ledger ll ON ll.loan_id = l.id
      ORDER BY l.id, ll.entry_date
    ''');
  }
}
