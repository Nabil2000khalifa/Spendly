import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/account_provider.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseCard({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.read<ExpenseProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final category = expenseProvider.getCategoryById(expense.categoryId);
    final account = accountProvider.getAccountById(expense.accountId);
    final isExpense = expense.isExpense;

    // Use the expense's own currency symbol — NOT the global settings symbol
    final currencySymbol = SettingsProvider.symbolForCurrency(expense.currency);
    final amountText =
        '${isExpense ? '-' : '+'}$currencySymbol${_formatAmount(expense.amount)}';

    return Dismissible(
      key: Key('expense_${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.06),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CategoryBubble(category: category),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              category?.name ?? 'Unknown',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (account != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '·',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 11),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                account.name,
                                style: TextStyle(
                                  color: Color(account.color),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(expense.date),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.38),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (expense.note != null && expense.note!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          expense.note!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.32),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      amountText,
                      style: TextStyle(
                        color: isExpense
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF10B981),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expense.currency,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.32),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount.abs() >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount.abs() >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(expDate).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (date.year != now.year) {
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _CategoryBubble extends StatelessWidget {
  final ExpenseCategory? category;
  const _CategoryBubble({this.category});

  @override
  Widget build(BuildContext context) {
    final color = category != null
        ? Color(category!.color)
        : const Color(0xFF6B7280);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Center(
        child: Text(
          category?.icon ?? '📦',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
