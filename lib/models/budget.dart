class Budget {
  final int? id;
  final int categoryId;
  final int amountPaise;
  final int month; // 1-12
  final int year;

  const Budget({
    this.id,
    required this.categoryId,
    required this.amountPaise,
    required this.month,
    required this.year,
  });
  
  double get amount => amountPaise / 100.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'amount_paise': amountPaise,
      'month': month,
      'year': year,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      amountPaise: map['amount_paise'] as int,
      month: map['month'] as int,
      year: map['year'] as int,
    );
  }

  Budget copyWith({
    int? id,
    int? categoryId,
    int? amountPaise,
    int? month,
    int? year,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amountPaise: amountPaise ?? this.amountPaise,
      month: month ?? this.month,
      year: year ?? this.year,
    );
  }
}
