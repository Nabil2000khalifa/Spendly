class AccountTransfer {
  final int? id;
  final int fromAccountId;
  final int toAccountId;
  final int amountPaise;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  const AccountTransfer({
    this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountPaise,
    required this.date,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'amount_paise': amountPaise,
      'date': date.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AccountTransfer.fromMap(Map<String, dynamic> map) {
    return AccountTransfer(
      id: map['id'] as int?,
      fromAccountId: map['from_account_id'] as int,
      toAccountId: map['to_account_id'] as int,
      amountPaise: map['amount_paise'] as int,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  AccountTransfer copyWith({
    int? id,
    int? fromAccountId,
    int? toAccountId,
    int? amountPaise,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return AccountTransfer(
      id: id ?? this.id,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amountPaise: amountPaise ?? this.amountPaise,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  double get amount => amountPaise / 100.0;
}
