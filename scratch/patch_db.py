import re
import os

filepath = 'lib/db/database_helper.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Bump version
content = re.sub(r'version: 3,', r'version: 4,', content)

# 2. _onCreate schemas
content = re.sub(r'amount REAL NOT NULL,', r'amount_paise INTEGER NOT NULL,', content)
content = re.sub(r'opening_balance REAL NOT NULL DEFAULT 0.0,', r'opening_balance_paise INTEGER NOT NULL DEFAULT 0,', content)
content = re.sub(r"'opening_balance': 0.0,", r"'opening_balance_paise': 0,", content)

# 3. v4 Migration script
migration_v4 = """
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
  }"""
content = re.sub(r'    \}\n  \}', migration_v4, content)

# 4. Fix getAccountBalance
content = re.sub(r'SELECT opening_balance FROM accounts', r'SELECT opening_balance_paise FROM accounts', content)
content = re.sub(r"accRow\['opening_balance'\] as double\?", r"(accRow['opening_balance_paise'] as num?)?.toDouble()", content)
content = re.sub(r"accRow\['opening_balance'\] as double", r"(accRow['opening_balance_paise'] as num).toDouble()", content)
# It's an integer paise, so divide by 100.
content = re.sub(r"\(accRow\['opening_balance_paise'\] as num\?\)\?\.toDouble\(\)", r"(((accRow['opening_balance_paise'] as num?)?.toDouble() ?? 0.0) / 100.0)", content)
content = re.sub(r"\(accRow\['opening_balance_paise'\] as num\)\.toDouble\(\)", r"(((accRow['opening_balance_paise'] as num).toDouble()) / 100.0)", content)


content = re.sub(r'SUM\(amount\) as total', r'SUM(amount_paise) as total_paise', content)
content = re.sub(r"row\['total'\] as double\?", r"row['total_paise'] as num?", content)
content = re.sub(r"row\['total'\] as double", r"row['total_paise'] as num", content)
content = re.sub(r"\(expRow\['total_paise'\] as num\?\)\?\.toDouble\(\) \?\? 0\.0", r"(((expRow['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0)", content)
content = re.sub(r"\(incRow\['total_paise'\] as num\?\)\?\.toDouble\(\) \?\? 0\.0", r"(((incRow['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0)", content)
content = re.sub(r"\(trOutRow\['total_paise'\] as num\?\)\?\.toDouble\(\) \?\? 0\.0", r"(((trOutRow['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0)", content)
content = re.sub(r"\(trInRow\['total_paise'\] as num\?\)\?\.toDouble\(\) \?\? 0\.0", r"(((trInRow['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0)", content)

# 5. Fix getAccountMetrics
content = re.sub(r"\(expRow\['total'\] as num\?\)\?\.toDouble\(\) \?\? 0\.0", r"(((expRow['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0)", content)
content = re.sub(r"\(incRow\['total'\] as num\?\)\?\.toDouble\(\) \?\? 0\.0", r"(((incRow['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0)", content)
content = re.sub(r"\(trOutRow\['total'\] as num\?\)\?\.toDouble\(\) \?\? 0\.0", r"(((trOutRow['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0)", content)
content = re.sub(r"\(trInRow\['total'\] as num\?\)\?\.toDouble\(\) \?\? 0\.0", r"(((trInRow['total_paise'] as num?)?.toDouble() ?? 0.0) / 100.0)", content)

# 6. Fix getExpensesByCategory and getMonthlyTotals
content = re.sub(r"double total = \(row\['total'\] as num\)\.toDouble\(\);", r"double total = (row['total_paise'] as num).toDouble() / 100.0;", content)
content = re.sub(r"totals\[type\] = \(row\['total'\] as num\)\.toDouble\(\);", r"totals[type] = (row['total_paise'] as num).toDouble() / 100.0;", content)
content = re.sub(r"totals\[type\]! \+ \(row\['total'\] as num\)\.toDouble\(\);", r"totals[type]! + (row['total_paise'] as num).toDouble() / 100.0;", content)

# 7. Fix getUnifiedAccountTransactionsRaw
content = re.sub(r"\(row\['amount'\] as num\)\.toDouble\(\)", r"((row['amount_paise'] as num).toDouble() / 100.0)", content)


with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done modifying database_helper.dart')
