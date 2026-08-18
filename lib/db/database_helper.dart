import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/person.dart';
import '../models/loan.dart';
import '../models/loan_ledger_entry.dart';
import '../models/account.dart';
import '../models/transfer.dart';

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
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ─── Schema Creation (fresh install) ─────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await _createExpenseTables(db);
    await _createLoanTables(db);
    await _createAccountTables(db);
    await _seedDefaultAccount(db);
  }

  // ─── Migration ─────────────────────────────────────────────────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createLoanTables(db);
    }
    if (oldVersion < 3) {
      await _createAccountTables(db);
      await db.execute('ALTER TABLE expenses ADD COLUMN account_id INTEGER REFERENCES accounts(id)');
      await db.execute('ALTER TABLE loans ADD COLUMN account_id INTEGER REFERENCES accounts(id)');
      await db.execute('ALTER TABLE loan_ledger ADD COLUMN account_id INTEGER REFERENCES accounts(id)');
      final primaryId = await _seedDefaultAccount(db);
      await db.execute('UPDATE expenses SET account_id = ? WHERE account_id IS NULL', [primaryId]);
      await db.execute('UPDATE loans SET account_id = ? WHERE account_id IS NULL', [primaryId]);
      await db.execute('UPDATE loan_ledger SET account_id = ? WHERE account_id IS NULL', [primaryId]);
    }
    if (oldVersion < 4) {
      await db.transaction((txn) async {
        // --- Migrate expenses ---
        await txn.execute('''
          CREATE TABLE expenses_v4 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount_paise INTEGER NOT NULL,
            category_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            note TEXT,
            type TEXT NOT NULL DEFAULT 'expense',
            currency TEXT NOT NULL DEFAULT 'INR',
            account_id INTEGER REFERENCES accounts(id),
            FOREIGN KEY (category_id) REFERENCES categories(id)
          )
        ''');
        await txn.execute('''
          INSERT INTO expenses_v4 (id, title, amount_paise, category_id, date, note, type, currency, account_id)
          SELECT id, title, CAST(ROUND(amount * 100) AS INTEGER), category_id, date, note, type, currency, account_id FROM expenses
        ''');
        await txn.execute('DROP TABLE expenses');
        await txn.execute('ALTER TABLE expenses_v4 RENAME TO expenses');

        // --- Migrate budgets ---
        await txn.execute('''
          CREATE TABLE budgets_v4 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NOT NULL,
            amount_paise INTEGER NOT NULL,
            month INTEGER NOT NULL,
            year INTEGER NOT NULL,
            UNIQUE(category_id, month, year),
            FOREIGN KEY (category_id) REFERENCES categories(id)
          )
        ''');
        await txn.execute('''
          INSERT INTO budgets_v4 (id, category_id, amount_paise, month, year)
          SELECT id, category_id, CAST(ROUND(amount * 100) AS INTEGER), month, year FROM budgets
        ''');
        await txn.execute('DROP TABLE budgets');
        await txn.execute('ALTER TABLE budgets_v4 RENAME TO budgets');

        // --- Migrate accounts ---
        await txn.execute('''
          CREATE TABLE accounts_v4 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            institution_name TEXT,
            account_number_last4 TEXT,
            opening_balance_paise INTEGER NOT NULL DEFAULT 0,
            currency TEXT NOT NULL DEFAULT 'INR',
            icon TEXT NOT NULL DEFAULT '🏦',
            color INTEGER NOT NULL DEFAULT 4285326335,
            is_active INTEGER NOT NULL DEFAULT 1,
            is_default INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await txn.execute('''
          INSERT INTO accounts_v4 (id, name, type, institution_name, account_number_last4, opening_balance_paise, currency, icon, color, is_active, is_default, created_at, updated_at)
          SELECT id, name, type, institution_name, account_number_last4, CAST(ROUND(opening_balance * 100) AS INTEGER), currency, icon, color, is_active, is_default, created_at, updated_at FROM accounts
        ''');
        await txn.execute('DROP TABLE accounts');
        await txn.execute('ALTER TABLE accounts_v4 RENAME TO accounts');

        // --- Migrate transfers ---
        await txn.execute('''
          CREATE TABLE transfers_v4 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_account_id INTEGER NOT NULL,
            to_account_id INTEGER NOT NULL,
            amount_paise INTEGER NOT NULL,
            date TEXT NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (from_account_id) REFERENCES accounts(id),
            FOREIGN KEY (to_account_id) REFERENCES accounts(id)
          )
        ''');
        await txn.execute('''
          INSERT INTO transfers_v4 (id, from_account_id, to_account_id, amount_paise, date, note, created_at)
          SELECT id, from_account_id, to_account_id, CAST(ROUND(amount * 100) AS INTEGER), date, note, created_at FROM transfers
        ''');
        await txn.execute('DROP TABLE transfers');
        await txn.execute('ALTER TABLE transfers_v4 RENAME TO transfers');
      });
    }
    if (oldVersion < 5) {
      // ─── v4 → v5: Normalise expense currency to match account currency ───
      // Expenses that still carry 'USD' from the old global-default bug are
      // updated to the currency of their linked account.  If the account
      // itself has 'USD' (a genuine USD account) the value stays unchanged.
      await db.execute('''
        UPDATE expenses
        SET currency = (
          SELECT a.currency FROM accounts a WHERE a.id = expenses.account_id
        )
        WHERE account_id IS NOT NULL
          AND currency = 'USD'
          AND EXISTS (
            SELECT 1 FROM accounts a
            WHERE a.id = expenses.account_id AND a.currency != 'USD'
          )
      ''');
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
        amount_paise INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        type TEXT NOT NULL DEFAULT 'expense',
        currency TEXT NOT NULL DEFAULT 'INR',
        account_id INTEGER REFERENCES accounts(id),
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        amount_paise INTEGER NOT NULL,
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
        account_id INTEGER REFERENCES accounts(id),
        FOREIGN KEY (person_id) REFERENCES persons(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE loan_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER NOT NULL,
        account_id INTEGER,
        entry_type TEXT NOT NULL,
        amount_paise INTEGER NOT NULL,
        description TEXT NOT NULL,
        payment_method TEXT,
        entry_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (loan_id) REFERENCES loans(id),
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      )
    ''');
  }

  // ─── Account Tables (v3) ───────────────────────────────────────────────────

  Future<void> _createAccountTables(Database db) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        institution_name TEXT,
        account_number_last4 TEXT,
        opening_balance_paise INTEGER NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'INR',
        icon TEXT NOT NULL DEFAULT '🏦',
        color INTEGER NOT NULL DEFAULT 4285326335,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_account_id INTEGER NOT NULL,
        to_account_id INTEGER NOT NULL,
        amount_paise INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (from_account_id) REFERENCES accounts(id),
        FOREIGN KEY (to_account_id) REFERENCES accounts(id)
      )
    ''');
  }

  Future<int> _seedDefaultAccount(Database db, {String currency = 'INR'}) async {
    final now = DateTime.now().toIso8601String();
    return await db.insert('accounts', {
      'name': 'Primary Account',
      'type': 'bank',
      'institution_name': null,
      'account_number_last4': null,
      'opening_balance_paise': 0,
      'currency': currency,
      'icon': '🏦',
      'color': 0xFF6C63FF,
      'is_active': 1,
      'is_default': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  // ─── Clear All User Data ──────────────────────────────────────────────────

  /// Completely wipes all user financial data and re-seeds default categories.
  /// Does NOT delete the database itself or migration metadata.
  Future<void> clearAllUserData() async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete in order to respect foreign key relationships
      await txn.delete('loan_ledger');
      await txn.delete('loans');
      await txn.delete('persons');
      await txn.delete('expenses');
      await txn.delete('budgets');
      await txn.delete('transfers');
      await txn.delete('accounts');
      // Remove user-created categories (keep none — reseed defaults)
      await txn.delete('categories');
      // Re-seed default categories
      for (final cat in defaultCategories) {
        await txn.insert('categories', cat.toMap()..remove('id'));
      }
      // Re-seed the primary account with INR
      final now = DateTime.now().toIso8601String();
      await txn.insert('accounts', {
        'name': 'Primary Account',
        'type': 'bank',
        'institution_name': null,
        'account_number_last4': null,
        'opening_balance_paise': 0,
        'currency': 'INR',
        'icon': '🏦',
        'color': 0xFF6C63FF,
        'is_active': 1,
        'is_default': 1,
        'created_at': now,
        'updated_at': now,
      });
    });
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

  Future<Map<int, double>> getExpensesByCategory(int month, int year, {int? accountId}) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();

    String query = '''
      SELECT category_id, SUM(amount_paise) as total_paise
      FROM expenses
      WHERE date >= ? AND date < ? AND type = 'expense'
    ''';
    final args = <dynamic>[start, end];

    if (accountId != null) {
      query += ' AND account_id = ?';
      args.add(accountId);
    }

    query += ' GROUP BY category_id';

    final result = await db.rawQuery(query, args);

    return {
      for (final row in result)
        (row['category_id'] as int): (row['total_paise'] as num).toDouble() / 100.0
    };
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals(int months, {int? accountId}) async {
    final db = await database;
    final now = DateTime.now();
    final results = <Map<String, dynamic>>[];

    for (int i = months - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final start = DateTime(date.year, date.month, 1).toIso8601String();
      final end = DateTime(date.year, date.month + 1, 1).toIso8601String();

      String query = '''
        SELECT 
          SUM(CASE WHEN type = 'expense' THEN amount_paise ELSE 0 END) as total_expense_paise,
          SUM(CASE WHEN type = 'income' THEN amount_paise ELSE 0 END) as total_income_paise
        FROM expenses
        WHERE date >= ? AND date < ?
      ''';
      final args = <dynamic>[start, end];

      if (accountId != null) {
        query += ' AND account_id = ?';
        args.add(accountId);
      }

      final row = await db.rawQuery(query, args);
      results.add({
        'month': date.month,
        'year': date.year,
        'expense': (row.first['total_expense_paise'] as num?)?.toDouble() != null ? (row.first['total_expense_paise'] as num).toDouble() / 100.0 : 0.0,
        'income': (row.first['total_income_paise'] as num?)?.toDouble() != null ? (row.first['total_income_paise'] as num).toDouble() / 100.0 : 0.0,
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

  // ─── Accounts ─────────────────────────────────────────────────────────────

  Future<List<Account>> getAccounts({bool includeInactive = false}) async {
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'is_default DESC, name ASC',
    );
    return maps.map(Account.fromMap).toList();
  }

  Future<Account?> getAccount(int id) async {
    final db = await database;
    final maps = await db.query('accounts', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  Future<int> insertAccount(Account account) async {
    final db = await database;
    if (account.isDefault) {
      await db.update('accounts', {'is_default': 0});
    }
    return await db.insert('accounts', account.toMap()..remove('id'));
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    if (account.isDefault) {
      await db.update('accounts', {'is_default': 0}, where: 'id != ?', whereArgs: [account.id]);
    }
    return await db.update('accounts', account.toMap(), where: 'id = ?', whereArgs: [account.id]);
  }

  Future<void> setDefaultAccount(int accountId) async {
    final db = await database;
    await db.update('accounts', {'is_default': 0});
    await db.update(
      'accounts',
      {'is_default': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  Future<void> setAccountActive(int accountId, bool isActive) async {
    final db = await database;
    await db.update(
      'accounts',
      {'is_active': isActive ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  Future<bool> hasAccountTransactions(int accountId) async {
    final db = await database;
    final expCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM expenses WHERE account_id = ?', [accountId])) ?? 0;
    if (expCount > 0) return true;
    final trCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transfers WHERE from_account_id = ? OR to_account_id = ?', [accountId, accountId])) ?? 0;
    if (trCount > 0) return true;
    final loanCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM loans WHERE account_id = ?', [accountId])) ?? 0;
    if (loanCount > 0) return true;
    final ledgerCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM loan_ledger WHERE account_id = ?', [accountId])) ?? 0;
    return ledgerCount > 0;
  }

  // ─── Account Balances Calculation ─────────────────────────────────────────

  Future<double> getAccountBalance(int accountId) async {
    final db = await database;
    final accMap = await db.query('accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
    if (accMap.isEmpty) return 0.0;
    final account = Account.fromMap(accMap.first);
    double balance = account.openingBalance;

    // Expenses & Income
    final expRes = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'income' THEN amount_paise ELSE 0 END) as income_paise,
        SUM(CASE WHEN type = 'expense' THEN amount_paise ELSE 0 END) as expense_paise
      FROM expenses
      WHERE account_id = ?
    ''', [accountId]);
    if (expRes.isNotEmpty) {
      final inc = ((expRes.first['income_paise'] as num?)?.toDouble() ?? 0.0) / 100.0;
      final exp = ((expRes.first['expense_paise'] as num?)?.toDouble() ?? 0.0) / 100.0;
      balance += inc - exp;
    }

    // Transfers In (+)
    final trIn = await db.rawQuery('SELECT SUM(amount_paise) as total_paise FROM transfers WHERE to_account_id = ?', [accountId]);
    if (trIn.isNotEmpty) {
      balance += ((trIn.first['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0;
    }

    // Transfers Out (-)
    final trOut = await db.rawQuery('SELECT SUM(amount_paise) as total_paise FROM transfers WHERE from_account_id = ?', [accountId]);
    if (trOut.isNotEmpty) {
      balance -= ((trOut.first['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0;
    }

    // Loans Lent principal (-) where loan account_id = accountId
    final lentRes = await db.rawQuery('''
      SELECT SUM(principal_paise) as total 
      FROM loans 
      WHERE type = 'lent' AND status != 'cancelled' AND account_id = ?
    ''', [accountId]);
    if (lentRes.isNotEmpty) {
      balance -= ((lentRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;
    }

    // Loans Borrowed principal (+) where loan account_id = accountId
    final borRes = await db.rawQuery('''
      SELECT SUM(principal_paise) as total 
      FROM loans 
      WHERE type = 'borrowed' AND status != 'cancelled' AND account_id = ?
    ''', [accountId]);
    if (borRes.isNotEmpty) {
      balance += ((borRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;
    }

    // Loan Payments & Repayments in ledger where account_id = accountId
    final ledgerRes = await db.rawQuery('''
      SELECT ll.amount_paise, l.type as loan_type
      FROM loan_ledger ll
      JOIN loans l ON ll.loan_id = l.id
      WHERE ll.entry_type = 'payment' AND ll.account_id = ?
    ''', [accountId]);
    for (final row in ledgerRes) {
      final amt = ((row['amount_paise'] as num).toDouble()) / 100.0;
      final isLent = row['loan_type'] == 'lent';
      if (isLent) {
        balance += amt; // Money received back for money lent (+)
      } else {
        balance -= amt; // Money paid back for money borrowed (-)
      }
    }

    return balance;
  }

  // ─── Transfers ─────────────────────────────────────────────────────────────

  Future<int> insertTransfer(AccountTransfer transfer) async {
    final db = await database;
    return await db.insert('transfers', transfer.toMap()..remove('id'));
  }

  Future<List<AccountTransfer>> getTransfers({int? accountId}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (accountId != null) {
      maps = await db.query(
        'transfers',
        where: 'from_account_id = ? OR to_account_id = ?',
        whereArgs: [accountId, accountId],
        orderBy: 'date DESC, created_at DESC',
      );
    } else {
      maps = await db.query('transfers', orderBy: 'date DESC, created_at DESC');
    }
    return maps.map(AccountTransfer.fromMap).toList();
  }

  Future<int> deleteTransfer(int id) async {
    final db = await database;
    return await db.delete('transfers', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Account Metrics & Unified Ledger ──────────────────────────────────────

  Future<Map<String, double>> getAccountMetrics(int accountId) async {
    final db = await database;
    final expRes = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'income' THEN amount_paise ELSE 0 END) as income_paise,
        SUM(CASE WHEN type = 'expense' THEN amount_paise ELSE 0 END) as expense_paise
      FROM expenses
      WHERE account_id = ?
    ''', [accountId]);
    final totalIncome = ((expRes.first['income_paise'] as num?)?.toDouble() ?? 0.0) / 100.0;
    final totalExpense = ((expRes.first['expense_paise'] as num?)?.toDouble() ?? 0.0) / 100.0;

    final trInRes = await db.rawQuery('SELECT SUM(amount_paise) as total_paise FROM transfers WHERE to_account_id = ?', [accountId]);
    final transfersIn = ((trInRes.first['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0;

    final trOutRes = await db.rawQuery('SELECT SUM(amount_paise) as total_paise FROM transfers WHERE from_account_id = ?', [accountId]);
    final transfersOut = ((trOutRes.first['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0;

    final lentRes = await db.rawQuery('''
      SELECT SUM(principal_paise) as total 
      FROM loans 
      WHERE type = 'lent' AND status != 'cancelled' AND account_id = ?
    ''', [accountId]);
    final loansLent = ((lentRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

    final borRes = await db.rawQuery('''
      SELECT SUM(principal_paise) as total 
      FROM loans 
      WHERE type = 'borrowed' AND status != 'cancelled' AND account_id = ?
    ''', [accountId]);
    final loansBorrowed = ((borRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

    final repRes = await db.rawQuery('''
      SELECT SUM(amount_paise) as total 
      FROM loan_ledger 
      WHERE entry_type = 'payment' AND account_id = ?
    ''', [accountId]);
    final loanRepayments = ((repRes.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'transfersIn': transfersIn,
      'transfersOut': transfersOut,
      'loansLent': loansLent,
      'loansBorrowed': loansBorrowed,
      'loanRepayments': loanRepayments,
    };
  }

  Future<List<Map<String, dynamic>>> getUnifiedAccountTransactionsRaw(int accountId) async {
    final db = await database;
    final items = <Map<String, dynamic>>[];

    // 1. Expenses & Incomes
    final expMaps = await db.rawQuery('''
      SELECT e.*, c.icon as cat_icon, c.name as cat_name 
      FROM expenses e
      LEFT JOIN categories c ON e.category_id = c.id
      WHERE e.account_id = ?
    ''', [accountId]);
    for (final row in expMaps) {
      final isExp = row['type'] == 'expense';
      items.add({
        'id': 'exp_${row['id']}',
        'title': row['title'] as String,
        'subtitle': (row['cat_name'] as String?) ?? 'General',
        'amount': ((row['amount_paise'] as num).toDouble() / 100.0),
        'isPositive': !isExp,
        'itemType': isExp ? 'expense' : 'income',
        'date': row['date'] as String,
        'icon': (row['cat_icon'] as String?) ?? (isExp ? '💸' : '💰'),
        'note': row['note'] as String?,
      });
    }

    // 2. Transfers Out
    final trOutMaps = await db.rawQuery('''
      SELECT t.*, a.name as target_name, a.icon as target_icon
      FROM transfers t
      JOIN accounts a ON t.to_account_id = a.id
      WHERE t.from_account_id = ?
    ''', [accountId]);
    for (final row in trOutMaps) {
      items.add({
        'id': 'tr_out_${row['id']}',
        'title': 'Transfer to ${row['target_name']}',
        'subtitle': 'Transfer Out',
        'amount': ((row['amount_paise'] as num).toDouble() / 100.0),
        'isPositive': false,
        'itemType': 'transfer_out',
        'date': row['date'] as String,
        'icon': (row['target_icon'] as String?) ?? '↗️',
        'note': row['note'] as String?,
      });
    }

    // 3. Transfers In
    final trInMaps = await db.rawQuery('''
      SELECT t.*, a.name as source_name, a.icon as source_icon
      FROM transfers t
      JOIN accounts a ON t.from_account_id = a.id
      WHERE t.to_account_id = ?
    ''', [accountId]);
    for (final row in trInMaps) {
      items.add({
        'id': 'tr_in_${row['id']}',
        'title': 'Transfer from ${row['source_name']}',
        'subtitle': 'Transfer In',
        'amount': ((row['amount_paise'] as num).toDouble() / 100.0),
        'isPositive': true,
        'itemType': 'transfer_in',
        'date': row['date'] as String,
        'icon': (row['source_icon'] as String?) ?? '↘️',
        'note': row['note'] as String?,
      });
    }

    // 4. Loan Ledger Entries
    final loanLedgerMaps = await db.rawQuery('''
      SELECT ll.*, l.type as loan_type, p.name as person_name
      FROM loan_ledger ll
      JOIN loans l ON ll.loan_id = l.id
      JOIN persons p ON l.person_id = p.id
      WHERE ll.account_id = ? AND ll.entry_type IN ('principal', 'payment')
    ''', [accountId]);
    for (final row in loanLedgerMaps) {
      final entryType = row['entry_type'] as String;
      final loanType = row['loan_type'] as String;
      final personName = row['person_name'] as String;
      final amt = ((row['amount_paise'] as num).toDouble()) / 100.0;
      bool isPos = false;
      String title = row['description'] as String;

      if (entryType == 'principal') {
        if (loanType == 'lent') {
          isPos = false;
          title = 'Lent to $personName';
        } else {
          isPos = true;
          title = 'Borrowed from $personName';
        }
      } else if (entryType == 'payment') {
        if (loanType == 'lent') {
          isPos = true;
          title = 'Repayment from $personName';
        } else {
          isPos = false;
          title = 'Repayment to $personName';
        }
      }

      items.add({
        'id': 'loan_ll_${row['id']}',
        'title': title,
        'subtitle': 'Loan ($personName)',
        'amount': amt,
        'isPositive': isPos,
        'itemType': 'loan',
        'date': row['entry_date'] as String,
        'icon': isPos ? '🤝' : '📤',
        'note': row['description'] as String?,
      });
    }

    return items;
  }
}
