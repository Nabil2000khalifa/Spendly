import 'package:flutter/material.dart';
import 'loan_ledger_entry.dart';
import 'person.dart';

// ─── Loan Status Constants ────────────────────────────────────────────────────

class LoanStatus {
  static const active = 'active';
  static const partial = 'partial';
  static const paid = 'paid';
  static const overdue = 'overdue';
  static const cancelled = 'cancelled';
}

// ─── Loan Model ──────────────────────────────────────────────────────────────

class Loan {
  final int? id;
  final int personId;
  final int? accountId;
  final String type; // 'lent' | 'borrowed'
  final int principalPaise; // stored as amount × 100 for integer arithmetic
  final bool interestEnabled;
  final String interestType; // 'percentage' | 'fixed'
  final double interestRate;
  final String interestPeriod; // 'one_time' | 'monthly' | 'yearly'
  final DateTime startDate;
  final DateTime? dueDate;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Loan({
    this.id,
    required this.personId,
    this.accountId,
    required this.type,
    required this.principalPaise,
    required this.interestEnabled,
    this.interestType = 'percentage',
    this.interestRate = 0.0,
    this.interestPeriod = 'one_time',
    required this.startDate,
    this.dueDate,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get principalAmount => principalPaise / 100.0;
  bool get isLent => type == 'lent';
  bool get isBorrowed => type == 'borrowed';
  bool get isPaid => status == LoanStatus.paid;
  bool get isCancelled => status == LoanStatus.cancelled;
  bool get isOverdue => status == LoanStatus.overdue;
  bool get isActive => status == LoanStatus.active || status == LoanStatus.partial;

  /// Calculates interest not yet committed to the ledger (for display only).
  double computeAccruedInterest(double alreadyChargedInterest) {
    if (!interestEnabled || interestType == 'fixed') return 0;
    if (interestPeriod == 'one_time') return 0;

    final now = DateTime.now();
    double periodsElapsed;
    if (interestPeriod == 'monthly') {
      periodsElapsed =
          ((now.year - startDate.year) * 12 + (now.month - startDate.month))
              .toDouble();
    } else {
      // yearly
      periodsElapsed = (now.year - startDate.year) +
          (now.month - startDate.month) / 12.0;
    }
    periodsElapsed = periodsElapsed.clamp(0, double.infinity);

    final totalAccrued = principalAmount * (interestRate / 100) * periodsElapsed;
    return (totalAccrued - alreadyChargedInterest).clamp(0, double.infinity);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'person_id': personId,
        'account_id': accountId,
        'type': type,
        'principal_paise': principalPaise,
        'interest_enabled': interestEnabled ? 1 : 0,
        'interest_type': interestType,
        'interest_rate': interestRate,
        'interest_period': interestPeriod,
        'start_date': startDate.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'status': status,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Loan.fromMap(Map<String, dynamic> map) => Loan(
        id: map['id'] as int?,
        personId: map['person_id'] as int,
        accountId: map['account_id'] as int?,
        type: map['type'] as String,
        principalPaise: map['principal_paise'] as int,
        interestEnabled: (map['interest_enabled'] as int) == 1,
        interestType: (map['interest_type'] as String?) ?? 'percentage',
        interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0.0,
        interestPeriod: (map['interest_period'] as String?) ?? 'one_time',
        startDate: DateTime.parse(map['start_date'] as String),
        dueDate: map['due_date'] != null
            ? DateTime.parse(map['due_date'] as String)
            : null,
        status: map['status'] as String,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Loan copyWith({
    int? id,
    int? personId,
    int? accountId,
    String? type,
    int? principalPaise,
    bool? interestEnabled,
    String? interestType,
    double? interestRate,
    String? interestPeriod,
    DateTime? startDate,
    DateTime? dueDate,
    String? status,
    String? notes,
    DateTime? updatedAt,
  }) =>
      Loan(
        id: id ?? this.id,
        personId: personId ?? this.personId,
        accountId: accountId ?? this.accountId,
        type: type ?? this.type,
        principalPaise: principalPaise ?? this.principalPaise,
        interestEnabled: interestEnabled ?? this.interestEnabled,
        interestType: interestType ?? this.interestType,
        interestRate: interestRate ?? this.interestRate,
        interestPeriod: interestPeriod ?? this.interestPeriod,
        startDate: startDate ?? this.startDate,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}

// ─── LoanWithDetails (View Model) ─────────────────────────────────────────────

class LoanWithDetails {
  final Loan loan;
  final Person person;
  final List<LoanLedgerEntry> ledger;

  LoanWithDetails({
    required this.loan,
    required this.person,
    required this.ledger,
  });

  double get principalAmount => loan.principalAmount;

  double get totalInterestCharged => ledger
      .where((e) => e.isInterest || e.isAdjustment)
      .fold(0.0, (s, e) => s + e.amount);

  double get totalPaid =>
      ledger.where((e) => e.isPayment).fold(0.0, (s, e) => s + e.amount);

  double get totalAmount => principalAmount + totalInterestCharged;

  double get balance => (totalAmount - totalPaid).clamp(0.0, double.infinity);

  double get outstandingInterest =>
      (totalInterestCharged - totalPaid.clamp(0.0, totalInterestCharged))
          .clamp(0.0, double.infinity);

  double get accruedUncommittedInterest =>
      loan.computeAccruedInterest(totalInterestCharged);

  double get progressPct =>
      totalAmount > 0 ? (totalPaid / totalAmount).clamp(0.0, 1.0) : 0.0;

  String get computedStatus {
    if (loan.isCancelled) return LoanStatus.cancelled;
    if (balance <= 0.01) return LoanStatus.paid;
    if (loan.dueDate != null &&
        loan.dueDate!.isBefore(DateTime.now()) &&
        balance > 0.01) return LoanStatus.overdue;
    if (totalPaid > 0.01) return LoanStatus.partial;
    return LoanStatus.active;
  }

  bool get isDueSoon {
    if (loan.dueDate == null || balance <= 0.01 || loan.isCancelled) {
      return false;
    }
    final days = loan.dueDate!.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 7;
  }

  int get daysOverdue {
    if (loan.dueDate == null) return 0;
    final diff = DateTime.now().difference(loan.dueDate!).inDays;
    return diff > 0 ? diff : 0;
  }

  Color get statusColor {
    switch (computedStatus) {
      case LoanStatus.paid:
        return const Color(0xFF10B981);
      case LoanStatus.overdue:
        return const Color(0xFFEF4444);
      case LoanStatus.partial:
        return const Color(0xFF3B82F6);
      case LoanStatus.cancelled:
        return const Color(0xFF6B7280);
      default:
        return isDueSoon ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B);
    }
  }

  String get statusLabel {
    switch (computedStatus) {
      case LoanStatus.paid:
        return 'Fully Paid';
      case LoanStatus.overdue:
        return '$daysOverdue days overdue';
      case LoanStatus.partial:
        return 'Partially Paid';
      case LoanStatus.cancelled:
        return 'Cancelled';
      default:
        return isDueSoon ? 'Due Soon' : 'Active';
    }
  }
}

// ─── Loan Dashboard Summary ───────────────────────────────────────────────────

class LoanSummary {
  final double totalToReceive;
  final double totalToPay;
  final double overdueAmount;
  final int activeCount;
  final int overdueCount;
  final double totalInterestEarned;
  final double totalInterestOwed;

  const LoanSummary({
    required this.totalToReceive,
    required this.totalToPay,
    required this.overdueAmount,
    required this.activeCount,
    required this.overdueCount,
    required this.totalInterestEarned,
    required this.totalInterestOwed,
  });

  double get netPosition => totalToReceive - totalToPay;

  static const empty = LoanSummary(
    totalToReceive: 0,
    totalToPay: 0,
    overdueAmount: 0,
    activeCount: 0,
    overdueCount: 0,
    totalInterestEarned: 0,
    totalInterestOwed: 0,
  );
}
