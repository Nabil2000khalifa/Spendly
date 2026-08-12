class ExpenseCategory {
  final int? id;
  final String name;
  final String icon;
  final int color;

  const ExpenseCategory({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as int,
    );
  }

  ExpenseCategory copyWith({int? id, String? name, String? icon, int? color}) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}

/// Default categories pre-seeded into the database
final List<ExpenseCategory> defaultCategories = [
  const ExpenseCategory(name: 'Food & Dining',    icon: '🍔', color: 0xFFFF6B6B),
  const ExpenseCategory(name: 'Transport',         icon: '🚗', color: 0xFF4ECDC4),
  const ExpenseCategory(name: 'Shopping',          icon: '🛍️', color: 0xFFFFE66D),
  const ExpenseCategory(name: 'Health',            icon: '💊', color: 0xFF95E1D3),
  const ExpenseCategory(name: 'Entertainment',     icon: '🎮', color: 0xFFA855F7),
  const ExpenseCategory(name: 'Bills & Utilities', icon: '💡', color: 0xFFF59E0B),
  const ExpenseCategory(name: 'Education',         icon: '📚', color: 0xFF3B82F6),
  const ExpenseCategory(name: 'Travel',            icon: '✈️', color: 0xFF06B6D4),
  const ExpenseCategory(name: 'Salary / Income',  icon: '💰', color: 0xFF10B981),
  const ExpenseCategory(name: 'Other',             icon: '📦', color: 0xFF6B7280),
];
