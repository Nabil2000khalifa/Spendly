import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/person.dart';
import '../models/loan.dart';
import '../models/loan_ledger_entry.dart';

class LoanProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Person> _persons = [];
  List<LoanWithDetails> _loans = [];
  LoanSummary _summary = LoanSummary.empty;

  // ─── Filter state ─────────────────────────────────────────────────────────
  String _typeFilter = 'all'; // 'all' | 'lent' | 'borrowed'
  String _statusFilter = 'active'; // 'active' | 'paid' | 'overdue' | 'all'
  String _searchQuery = '';

  List<Person> get persons => _persons;
  List<LoanWithDetails> get allLoans => _loans;
  LoanSummary get summary => _summary;
  String get typeFilter => _typeFilter;
  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;

  List<LoanWithDetails> get filteredLoans {
    var result = _loans;

    // Type filter
    if (_typeFilter != 'all') {
      result = result.where((l) => l.loan.type == _typeFilter).toList();
    }

    // Status filter
    if (_statusFilter == 'active') {
      result = result
          .where((l) =>
              l.computedStatus == LoanStatus.active ||
              l.computedStatus == LoanStatus.partial ||
              l.computedStatus == LoanStatus.overdue)
          .toList();
    } else if (_statusFilter == 'paid') {
      result = result
          .where((l) => l.computedStatus == LoanStatus.paid)
          .toList();
    } else if (_statusFilter == 'overdue') {
      result = result
          .where((l) => l.computedStatus == LoanStatus.overdue)
          .toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((l) => l.person.name.toLowerCase().contains(q))
          .toList();
    }

    return result;
  }

  void setTypeFilter(String f) {
    if (_typeFilter == f) return;
    _typeFilter = f;
    notifyListeners();
  }

  void setStatusFilter(String f) {
    if (_statusFilter == f) return;
    _statusFilter = f;
    notifyListeners();
  }

  void setFilters(String type, String status) {
    if (_typeFilter == type && _statusFilter == status) return;
    _typeFilter = type;
    _statusFilter = status;
    notifyListeners();
  }

  void setSearch(String q) {
    if (_searchQuery == q) return;
    _searchQuery = q;
    notifyListeners();
  }

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await loadPersons();
    await loadLoans();
  }

  Future<void> loadPersons() async {
    _persons = await _db.getPersons();
    notifyListeners();
  }

  Future<void> loadLoans() async {
    final rawLoans = await _db.getLoans();
    final personMap = {for (final p in _persons) if (p.id != null) p.id!: p};
    final withDetails = <LoanWithDetails>[];

    for (final loan in rawLoans) {
      if (loan.isCancelled) continue; // skip cancelled in main list
      final person = personMap[loan.personId] ?? await _db.getPerson(loan.personId);
      if (person == null) continue;
      final ledger = await _db.getLedgerForLoan(loan.id!);
      final detail = LoanWithDetails(loan: loan, person: person, ledger: ledger);
      // Auto-sync status if needed
      final computed = detail.computedStatus;
      if (computed != loan.status) {
        await _db.updateLoanStatus(loan.id!, computed);
      }
      withDetails.add(detail);
    }

    _loans = withDetails;
    _computeSummary();
    notifyListeners();
  }

  void _computeSummary() {
    double toReceive = 0;
    double toPay = 0;
    double overdueAmt = 0;
    int activeCount = 0;
    int overdueCount = 0;
    double interestEarned = 0;
    double interestOwed = 0;

    for (final ld in _loans) {
      final status = ld.computedStatus;
      if (status == LoanStatus.paid) continue;

      if (ld.loan.isLent) {
        toReceive += ld.balance;
        interestEarned += ld.totalInterestCharged;
      } else {
        toPay += ld.balance;
        interestOwed += ld.totalInterestCharged;
      }

      if (status == LoanStatus.overdue) {
        overdueAmt += ld.balance;
        overdueCount++;
      } else {
        activeCount++;
      }
    }

    _summary = LoanSummary(
      totalToReceive: toReceive,
      totalToPay: toPay,
      overdueAmount: overdueAmt,
      activeCount: activeCount,
      overdueCount: overdueCount,
      totalInterestEarned: interestEarned,
      totalInterestOwed: interestOwed,
    );
  }

  // ─── Person CRUD ──────────────────────────────────────────────────────────

  Future<Person> addPerson(Person person) async {
    final id = await _db.insertPerson(person);
    await loadPersons();
    return person.copyWith(id: id);
  }

  Future<void> updatePerson(Person person) async {
    await _db.updatePerson(person);
    await loadPersons();
    await loadLoans();
  }

  Person? getPersonById(int id) {
    try {
      return _persons.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns net balance with a person.
  /// Positive = they owe me, Negative = I owe them.
  double netBalanceWithPerson(int personId) {
    double net = 0;
    for (final ld in _loans) {
      if (ld.person.id != personId) continue;
      if (ld.computedStatus == LoanStatus.paid) continue;
      if (ld.loan.isLent) {
        net += ld.balance;
      } else {
        net -= ld.balance;
      }
    }
    return net;
  }

  List<LoanWithDetails> loansForPerson(int personId) =>
      _loans.where((l) => l.person.id == personId).toList();

  // ─── Loan CRUD ────────────────────────────────────────────────────────────

  Future<void> addLoan(Loan loan) async {
    final now = DateTime.now();
    final id = await _db.insertLoan(loan);

    // Add principal ledger entry
    await _db.insertLedgerEntry(LoanLedgerEntry(
      loanId: id,
      accountId: loan.accountId,
      entryType: 'principal',
      amountPaise: loan.principalPaise,
      description: loan.isLent
          ? 'Lent to ${(await _db.getPerson(loan.personId))?.name ?? ''}'
          : 'Borrowed from ${(await _db.getPerson(loan.personId))?.name ?? ''}',
      entryDate: loan.startDate,
      createdAt: now,
    ));

    // Auto-add one-time interest if applicable
    if (loan.interestEnabled) {
      final interestAmount = _computeOneTimeInterest(loan);
      if (interestAmount > 0 &&
          (loan.interestPeriod == 'one_time' ||
              loan.interestType == 'fixed')) {
        final interestPaise = (interestAmount * 100).round();
        await _db.insertLedgerEntry(LoanLedgerEntry(
          loanId: id,
          accountId: loan.accountId,
          entryType: 'interest',
          amountPaise: interestPaise,
          description: loan.interestType == 'fixed'
              ? 'Fixed interest: ${interestAmount.toStringAsFixed(2)}'
              : '${loan.interestRate}% one-time interest',
          entryDate: loan.startDate,
          createdAt: now,
        ));
      }
    }

    await loadLoans();
  }

  double _computeOneTimeInterest(Loan loan) {
    if (!loan.interestEnabled) return 0;
    if (loan.interestType == 'fixed') return loan.interestRate;
    if (loan.interestPeriod == 'one_time') {
      return loan.principalAmount * loan.interestRate / 100;
    }
    return 0;
  }

  Future<void> updateLoan(Loan loan) async {
    await _db.updateLoan(loan.copyWith(updatedAt: DateTime.now()));
    await loadLoans();
  }

  Future<LoanWithDetails?> getLoanDetails(int loanId) async {
    final l = _loans.firstWhere((l) => l.loan.id == loanId);
    return l;
  }

  // ─── Record Payment ───────────────────────────────────────────────────────

  Future<void> recordPayment({
    required LoanWithDetails loanDetails,
    required double amount,
    required String method,
    required DateTime date,
    int? accountId,
    String? note,
  }) async {
    final amtPaise = (amount * 100).round();
    final desc = note != null && note.isNotEmpty
        ? 'Payment via ${PaymentMethod.label(method)} — $note'
        : 'Payment via ${PaymentMethod.label(method)}';

    await _db.insertLedgerEntry(LoanLedgerEntry(
      loanId: loanDetails.loan.id!,
      accountId: accountId ?? loanDetails.loan.accountId,
      entryType: 'payment',
      amountPaise: amtPaise,
      description: desc,
      paymentMethod: method,
      entryDate: date,
      createdAt: DateTime.now(),
    ));

    // Update status
    final updatedLedger =
        await _db.getLedgerForLoan(loanDetails.loan.id!);
    final updated = LoanWithDetails(
        loan: loanDetails.loan, person: loanDetails.person, ledger: updatedLedger);
    await _db.updateLoanStatus(loanDetails.loan.id!, updated.computedStatus);

    await loadLoans();
  }

  // ─── Add Interest / Adjustment ────────────────────────────────────────────

  Future<void> addInterestEntry({
    required int loanId,
    required double amount,
    required String description,
    required DateTime date,
  }) async {
    final amtPaise = (amount * 100).round();
    await _db.insertLedgerEntry(LoanLedgerEntry(
      loanId: loanId,
      entryType: 'interest',
      amountPaise: amtPaise,
      description: description,
      entryDate: date,
      createdAt: DateTime.now(),
    ));

    await _db.updateLoanStatus(loanId, LoanStatus.active);
    await loadLoans();
  }

  Future<void> addAdjustmentEntry({
    required int loanId,
    required double amount,
    required String description,
    required DateTime date,
  }) async {
    final amtPaise = (amount * 100).round();
    await _db.insertLedgerEntry(LoanLedgerEntry(
      loanId: loanId,
      entryType: 'adjustment',
      amountPaise: amtPaise,
      description: description,
      entryDate: date,
      createdAt: DateTime.now(),
    ));
    await loadLoans();
  }

  // ─── Apply Accrued Interest ───────────────────────────────────────────────

  Future<void> applyAccruedInterest(LoanWithDetails ld) async {
    final accrued = ld.accruedUncommittedInterest;
    if (accrued <= 0) return;

    final period = ld.loan.interestPeriod == 'monthly' ? 'Monthly' : 'Yearly';
    await addInterestEntry(
      loanId: ld.loan.id!,
      amount: accrued,
      description:
          '$period ${ld.loan.interestRate}% interest applied (${DateTime.now().month}/${DateTime.now().year})',
      date: DateTime.now(),
    );
  }

  // ─── Mark as Paid ─────────────────────────────────────────────────────────

  Future<void> markAsPaid(LoanWithDetails ld) async {
    if (ld.balance <= 0) return;
    final remaining = ld.balance;
    await recordPayment(
      loanDetails: ld,
      amount: remaining,
      method: PaymentMethod.other,
      date: DateTime.now(),
      note: 'Marked as fully paid',
    );
  }

  // ─── Cancel Loan ─────────────────────────────────────────────────────────

  Future<void> cancelLoan(int loanId) async {
    await _db.insertLedgerEntry(LoanLedgerEntry(
      loanId: loanId,
      entryType: 'cancellation',
      amountPaise: 0,
      description: 'Loan cancelled',
      entryDate: DateTime.now(),
      createdAt: DateTime.now(),
    ));
    await _db.updateLoanStatus(loanId, LoanStatus.cancelled);
    await loadLoans();
  }

  // ─── Export ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllLoanDataForExport() async {
    return await _db.getAllLoanDataForExport();
  }
}
