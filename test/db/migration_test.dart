import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spendly/db/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v3 to v4 migration converts amount to amount_paise correctly', () async {
    final dbPath = [await getDatabasesPath(), 'migration_test.db'].join('/');
    await databaseFactory.deleteDatabase(dbPath);

    // 1. Create DB at version 3
    var db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          // Manually create v3 schema
          await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              icon TEXT NOT NULL,
              color INTEGER NOT NULL,
              type TEXT NOT NULL,
              is_default INTEGER NOT NULL DEFAULT 0
            )
          ''');
          
          await db.execute('''
            CREATE TABLE accounts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              type TEXT NOT NULL,
              institution_name TEXT,
              account_number_last4 TEXT,
              opening_balance REAL NOT NULL DEFAULT 0.0,
              currency TEXT NOT NULL DEFAULT 'USD',
              icon TEXT NOT NULL DEFAULT '🏦',
              color INTEGER NOT NULL DEFAULT 4285326335,
              is_active INTEGER NOT NULL DEFAULT 1,
              is_default INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
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
              account_id INTEGER REFERENCES accounts(id),
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
          
          await db.execute('''
            CREATE TABLE transfers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              from_account_id INTEGER NOT NULL,
              to_account_id INTEGER NOT NULL,
              amount REAL NOT NULL,
              date TEXT NOT NULL,
              note TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (from_account_id) REFERENCES accounts(id),
              FOREIGN KEY (to_account_id) REFERENCES accounts(id)
            )
          ''');
        },
      ),
    );

    // 2. Insert test data in v3 schema (using REAL values)
    await db.insert('categories', {
      'id': 1,
      'name': 'Food',
      'icon': '🍔',
      'color': 0xFF00FF00,
      'type': 'expense',
    });
    
    await db.insert('accounts', {
      'id': 1,
      'name': 'Main Account',
      'type': 'bank',
      'opening_balance': 150.75, // 150.75
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    
    await db.insert('accounts', {
      'id': 2,
      'name': 'Savings',
      'type': 'bank',
      'opening_balance': 0.0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await db.insert('expenses', {
      'title': 'Lunch',
      'amount': 45.20, // 45.20
      'category_id': 1,
      'date': DateTime.now().toIso8601String(),
      'account_id': 1,
    });

    await db.insert('budgets', {
      'category_id': 1,
      'amount': 500.0, // 500.0
      'month': 8,
      'year': 2024,
    });

    await db.insert('transfers', {
      'from_account_id': 1,
      'to_account_id': 2,
      'amount': 100.99, // 100.99
      'date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.close();

    // 3. Open DB at version 4 to trigger migration
    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onUpgrade: (db, oldVersion, newVersion) async {
          // This should mirror _onUpgrade in DatabaseHelper for v4
          if (oldVersion < 4) {
            await db.transaction((txn) async {
              await txn.execute('''
                CREATE TABLE expenses_v4 (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  title TEXT NOT NULL,
                  amount_paise INTEGER NOT NULL,
                  category_id INTEGER NOT NULL,
                  date TEXT NOT NULL,
                  note TEXT,
                  type TEXT NOT NULL DEFAULT 'expense',
                  currency TEXT NOT NULL DEFAULT 'USD',
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

              await txn.execute('''
                CREATE TABLE accounts_v4 (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  name TEXT NOT NULL,
                  type TEXT NOT NULL,
                  institution_name TEXT,
                  account_number_last4 TEXT,
                  opening_balance_paise INTEGER NOT NULL DEFAULT 0,
                  currency TEXT NOT NULL DEFAULT 'USD',
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
        },
      ),
    );

    // 4. Verify data in v4 schema (using INTEGER paise values)
    final accRows = await db.query('accounts', where: 'id = 1');
    expect(accRows.first['opening_balance_paise'], 15075);
    expect(accRows.first.containsKey('opening_balance'), false);

    final expRows = await db.query('expenses', where: 'title = ?', whereArgs: ['Lunch']);
    expect(expRows.first['amount_paise'], 4520);
    expect(expRows.first.containsKey('amount'), false);

    final budRows = await db.query('budgets');
    expect(budRows.first['amount_paise'], 50000);
    expect(budRows.first.containsKey('amount'), false);

    final trRows = await db.query('transfers');
    expect(trRows.first['amount_paise'], 10099);
    expect(trRows.first.containsKey('amount'), false);

    await db.close();
  });
}
