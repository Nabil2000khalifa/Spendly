class Person {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final DateTime createdAt;

  const Person({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    required this.createdAt,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory Person.fromMap(Map<String, dynamic> map) => Person(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Person copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? notes,
  }) =>
      Person(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
