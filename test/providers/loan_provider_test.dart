import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spendly/db/database_helper.dart';
import 'package:spendly/providers/loan_provider.dart';
import 'package:spendly/providers/account_provider.dart';
import 'package:spendly/models/person.dart';
import 'package:spendly/models/loan.dart';

class MockAccountProvider extends AccountProvider {
  int loadAccountsCallCount = 0;

  @override
  Future<void> loadAccounts() async {
    loadAccountsCallCount++;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LoanProvider mutation methods refresh AccountProvider', () {
    late LoanProvider loanProvider;
    late MockAccountProvider mockAccountProvider;
    late Person testPerson;
    late LoanWithDetails testLoanDetails;

    setUp(() async {
      mockAccountProvider = MockAccountProvider();
      loanProvider = LoanProvider();
      loanProvider.accountProvider = mockAccountProvider;
      
      final dbHelper = DatabaseHelper();
      // Wait for DB to init and clean up old data if necessary
      final db = await dbHelper.database;
      await db.delete('loan_ledger');
      await db.delete('loans');
      await db.delete('persons');
      await db.delete('accounts');
      await db.delete('expenses');

      testPerson = await loanProvider.addPerson(Person(
        name: 'Test Person',
        createdAt: DateTime.now(),
      ));

      await loanProvider.addLoan(Loan(
        personId: testPerson.id!,
        type: 'lent',
        principalPaise: 10000,
        interestEnabled: false,
        startDate: DateTime.now(),
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final loans = loanProvider.allLoans;
      testLoanDetails = loans.first;
      
      // Reset call count since addPerson and addLoan both might have called loadAccounts or other things
      // We will test individual methods next.
      mockAccountProvider.loadAccountsCallCount = 0;
    });

    test('addLoan calls loadAccounts', () async {
      await loanProvider.addLoan(Loan(
        personId: testPerson.id!,
        type: 'borrowed',
        principalPaise: 5000,
        interestEnabled: false,
        startDate: DateTime.now(),
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      expect(mockAccountProvider.loadAccountsCallCount, 1);
    });

    test('recordPayment calls loadAccounts', () async {
      await loanProvider.recordPayment(
        loanDetails: testLoanDetails,
        amount: 50.0,
        method: 'cash',
        date: DateTime.now(),
      );
      expect(mockAccountProvider.loadAccountsCallCount, 1);
    });

    test('addInterestEntry calls loadAccounts', () async {
      await loanProvider.addInterestEntry(
        loanId: testLoanDetails.loan.id!,
        amount: 10.0,
        description: 'Interest',
        date: DateTime.now(),
      );
      expect(mockAccountProvider.loadAccountsCallCount, 1);
    });

    test('addAdjustmentEntry calls loadAccounts', () async {
      await loanProvider.addAdjustmentEntry(
        loanId: testLoanDetails.loan.id!,
        amount: -5.0,
        description: 'Discount',
        date: DateTime.now(),
      );
      expect(mockAccountProvider.loadAccountsCallCount, 1);
    });

    test('markAsPaid calls loadAccounts', () async {
      await loanProvider.markAsPaid(testLoanDetails);
      // markAsPaid delegates to recordPayment, so it should call loadAccounts
      expect(mockAccountProvider.loadAccountsCallCount, 1);
    });

    test('cancelLoan calls loadAccounts', () async {
      await loanProvider.cancelLoan(testLoanDetails.loan.id!);
      expect(mockAccountProvider.loadAccountsCallCount, 1);
    });
  });
}
