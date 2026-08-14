class Account {
  final int? id;
  final String name;
  final String type; // 'bank' | 'cash' | 'wallet' | 'credit_card' | 'other'
  final String? institutionName;
  final String? accountNumberLast4;
  final int openingBalancePaise;
  final String currency;
  final String icon;
  final int color;
  final bool isActive;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Account({
    this.id,
    required this.name,
    required this.type,
    this.institutionName,
    this.accountNumberLast4,
    this.openingBalancePaise = 0,
    required this.currency,
    this.icon = '🏦',
    this.color = 0xFF6C63FF,
    this.isActive = true,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  static const typeBank = 'bank';
  static const typeCash = 'cash';
  static const typeWallet = 'wallet';
  static const typeCreditCard = 'credit_card';
  static const typeOther = 'other';

  static const types = [
    typeBank,
    typeCash,
    typeWallet,
    typeCreditCard,
    typeOther,
  ];

  static String typeLabel(String type) {
    switch (type) {
      case typeBank:
        return 'Bank Account';
      case typeCash:
        return 'Cash';
      case typeWallet:
        return 'Wallet';
      case typeCreditCard:
        return 'Credit Card';
      case typeOther:
      default:
        return 'Other';
    }
  }

  static String defaultIcon(String type) {
    switch (type) {
      case typeBank:
        return '🏦';
      case typeCash:
        return '💵';
      case typeWallet:
        return '👛';
      case typeCreditCard:
        return '💳';
      case typeOther:
      default:
        return '💰';
    }
  }

  String get typeDisplayName => typeLabel(type);

  String get accountNumberDisplay =>
      accountNumberLast4 != null && accountNumberLast4!.isNotEmpty
          ? '•••• $accountNumberLast4'
          : '';
          
  double get openingBalance => openingBalancePaise / 100.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'institution_name': institutionName,
      'account_number_last4': accountNumberLast4,
      'opening_balance_paise': openingBalancePaise,
      'currency': currency,
      'icon': icon,
      'color': color,
      'is_active': isActive ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      institutionName: map['institution_name'] as String?,
      accountNumberLast4: map['account_number_last4'] as String?,
      openingBalancePaise: map['opening_balance_paise'] as int? ?? ((map['opening_balance'] as num?)?.toDouble() ?? 0.0 * 100).round(), // fallback for old data during migration if ever needed
      currency: map['currency'] as String,
      icon: (map['icon'] as String?) ?? defaultIcon(map['type'] as String),
      color: map['color'] as int? ?? 0xFF6C63FF,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Account copyWith({
    int? id,
    String? name,
    String? type,
    String? institutionName,
    String? accountNumberLast4,
    int? openingBalancePaise,
    String? currency,
    String? icon,
    int? color,
    bool? isActive,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      institutionName: institutionName ?? this.institutionName,
      accountNumberLast4: accountNumberLast4 ?? this.accountNumberLast4,
      openingBalancePaise: openingBalancePaise ?? this.openingBalancePaise,
      currency: currency ?? this.currency,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
