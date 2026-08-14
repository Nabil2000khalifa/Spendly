import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spendly/db/database_helper.dart';
import 'package:spendly/models/account.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper Unified Transactions', () {
    late DatabaseHelper dbHelper;
    late int testAccountId;

    setUp(() async {
      dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      
      // Clean DB
      await db.delete('loan_ledger');
      await db.delete('loans');
      await db.delete('persons');
      await db.delete('expenses');
      await db.delete('transfers');
      await db.delete('accounts');

      // Setup data
      testAccountId = await dbHelper.insertAccount(Account(
        name: 'Test Account',
        type: 'bank',
        currency: 'USD',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final personId = await db.insert('persons', {
        'name': 'Test Person',
        'created_at': DateTime.now().toIso8601String(),
      });

      final loanId = await db.insert('loans', {
        'person_id': personId,
        'account_id': testAccountId,
        'type': 'lent',
        'principal_paise': 10000,
        'interest_enabled': 0,
        'start_date': DateTime.now().toIso8601String(),
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Insert Principal (Should be included)
      await db.insert('loan_ledger', {
        'loan_id': loanId,
        'account_id': testAccountId,
        'entry_type': 'principal',
        'amount_paise': 10000,
        'description': 'Principal disbursed',
        'entry_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Insert Interest (Should be excluded)
      await db.insert('loan_ledger', {
        'loan_id': loanId,
        'account_id': testAccountId,
        'entry_type': 'interest',
        'amount_paise': 500,
        'description': 'Interest accrued',
        'entry_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Insert Payment (Should be included)
      await db.insert('loan_ledger', {
        'loan_id': loanId,
        'account_id': testAccountId,
        'entry_type': 'payment',
        'amount_paise': 2000,
        'description': 'Partial payment',
        'entry_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Insert Adjustment (Should be excluded)
      await db.insert('loan_ledger', {
        'loan_id': loanId,
        'account_id': testAccountId,
        'entry_type': 'adjustment',
        'amount_paise': -100,
        'description': 'Adjustment',
        'entry_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Insert Cancellation (Should be excluded)
      await db.insert('loan_ledger', {
        'loan_id': loanId,
        'account_id': testAccountId,
        'entry_type': 'cancellation',
        'amount_paise': -8000,
        'description': 'Cancelled',
        'entry_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    test('getUnifiedAccountTransactionsRaw filters out non-cash ledger entries', () async {
      final items = await dbHelper.getUnifiedAccountTransactionsRaw(testAccountId);
      
      // Filter the items that came from loans
      final loanItems = items.where((item) => item['itemType'] == 'loan').toList();
      
      // There were 5 entries inserted into the ledger. Only 2 ('principal' and 'payment') should be returned.
      expect(loanItems.length, 2);
      
      // Verify the returned entries match what we expect for principal and payment
      final titles = loanItems.map((e) => e['title'] as String).toList();
      expect(titles.contains('Lent to Test Person'), true);
      expect(titles.contains('Repayment from Test Person'), true);
    });
  });
}
