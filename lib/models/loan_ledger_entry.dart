import 'package:flutter/material.dart';

class LoanLedgerEntry {
  final int? id;
  final int loanId;
  final int? accountId;
  final String entryType; // 'principal' | 'payment' | 'interest' | 'adjustment' | 'cancellation'
  final int amountPaise; // always positive (× 100)
  final String description;
  final String? paymentMethod; // 'cash' | 'upi' | 'bank' | 'other'
  final DateTime entryDate;
  final DateTime createdAt;

  const LoanLedgerEntry({
    this.id,
    required this.loanId,
    this.accountId,
    required this.entryType,
    required this.amountPaise,
    required this.description,
    this.paymentMethod,
    required this.entryDate,
    required this.createdAt,
  });

  double get amount => amountPaise / 100.0;

  bool get isPrincipal => entryType == 'principal';
  bool get isPayment => entryType == 'payment';
  bool get isInterest => entryType == 'interest';
  bool get isAdjustment => entryType == 'adjustment';
  bool get isCancellation => entryType == 'cancellation';

  /// Returns +amount for debt-increasing entries, -amount for payments.
  double get signedAmount {
    if (isPayment) return -amount;
    return amount;
  }

  Color get entryColor {
    if (isPayment) return const Color(0xFF10B981); // green
    if (isInterest || isAdjustment) return const Color(0xFFF59E0B); // amber
    if (isCancellation) return const Color(0xFF6B7280); // gray
    return const Color(0xFF6C63FF); // purple for principal
  }

  IconData get entryIcon {
    switch (entryType) {
      case 'principal':
        return Icons.account_balance_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'interest':
        return Icons.percent_rounded;
      case 'adjustment':
        return Icons.tune_rounded;
      case 'cancellation':
        return Icons.cancel_rounded;
      default:
        return Icons.circle;
    }
  }

  String get entryTypeLabel {
    switch (entryType) {
      case 'principal':
        return 'Loan Created';
      case 'payment':
        return 'Payment';
      case 'interest':
        return 'Interest';
      case 'adjustment':
        return 'Adjustment';
      case 'cancellation':
        return 'Cancelled';
      default:
        return entryType;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'loan_id': loanId,
        'account_id': accountId,
        'entry_type': entryType,
        'amount_paise': amountPaise,
        'description': description,
        'payment_method': paymentMethod,
        'entry_date': entryDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory LoanLedgerEntry.fromMap(Map<String, dynamic> map) => LoanLedgerEntry(
        id: map['id'] as int?,
        loanId: map['loan_id'] as int,
        accountId: map['account_id'] as int?,
        entryType: map['entry_type'] as String,
        amountPaise: map['amount_paise'] as int,
        description: map['description'] as String,
        paymentMethod: map['payment_method'] as String?,
        entryDate: DateTime.parse(map['entry_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// Available payment methods
class PaymentMethod {
  static const cash = 'cash';
  static const upi = 'upi';
  static const bank = 'bank';
  static const other = 'other';

  static const all = [cash, upi, bank, other];

  static String label(String method) {
    switch (method) {
      case cash:
        return 'Cash';
      case upi:
        return 'UPI';
      case bank:
        return 'Bank Transfer';
      default:
        return 'Other';
    }
  }

  static IconData icon(String method) {
    switch (method) {
      case cash:
        return Icons.money_rounded;
      case upi:
        return Icons.phone_android_rounded;
      case bank:
        return Icons.account_balance_rounded;
      default:
        return Icons.more_horiz_rounded;
    }
  }
}
