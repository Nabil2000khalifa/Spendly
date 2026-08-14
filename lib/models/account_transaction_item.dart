class AccountTransactionItem {
  final String id; // unique key
  final String title;
  final String subtitle;
  final double amount;
  final bool isPositive; // true if money entered account, false if money left
  final String itemType; // 'expense' | 'income' | 'transfer_in' | 'transfer_out' | 'loan'
  final DateTime date;
  final String icon;
  final String? note;

  const AccountTransactionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isPositive,
    required this.itemType,
    required this.date,
    required this.icon,
    this.note,
  });
}
