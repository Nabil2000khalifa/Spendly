class Expense {
  final int? id;
  final String title;
  final int amountPaise;
  final int categoryId;
  final int? accountId;
  final DateTime date;
  final String? note;
  final String type; // 'expense' or 'income'
  final String currency;

  const Expense({
    this.id,
    required this.title,
    required this.amountPaise,
    required this.categoryId,
    this.accountId,
    required this.date,
    this.note,
    required this.type,
    required this.currency,
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  
  double get amount => amountPaise / 100.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount_paise': amountPaise,
      'category_id': categoryId,
      'account_id': accountId,
      'date': date.toIso8601String(),
      'note': note,
      'type': type,
      'currency': currency,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      title: map['title'] as String,
      amountPaise: map['amount_paise'] as int,
      categoryId: map['category_id'] as int,
      accountId: map['account_id'] as int?,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      type: map['type'] as String,
      currency: map['currency'] as String,
    );
  }

  Expense copyWith({
    int? id,
    String? title,
    int? amountPaise,
    int? categoryId,
    int? accountId,
    DateTime? date,
    String? note,
    String? type,
    String? currency,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amountPaise: amountPaise ?? this.amountPaise,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      note: note ?? this.note,
      type: type ?? this.type,
      currency: currency ?? this.currency,
    );
  }
}
