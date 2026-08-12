import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final categories = provider.categories;

    // Only show expense-related categories (not income)
    final expCats = categories
        .where((c) => !c.name.toLowerCase().contains('income') &&
            !c.name.toLowerCase().contains('salary'))
        .toList();

    double totalBudget = provider.budgets.fold(0.0, (s, b) => s + b.amount);
    double totalSpent = 0;
    for (final cat in expCats) {
      if (cat.id != null) {
        totalSpent += provider.getSpentForCategory(cat.id!);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Budget',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_months[provider.selectedMonth]} ${provider.selectedYear}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Overall Budget Card ──────────────────────────
            if (totalBudget > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _OverallBudgetCard(
                    totalBudget: totalBudget,
                    totalSpent: totalSpent,
                    settings: settings,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Category Budget List ─────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, idx) {
                    final cat = expCats[idx];
                    final budget = provider.getBudgetForCategory(cat.id ?? -1);
                    final spent = provider.getSpentForCategory(cat.id ?? -1);

                    return _BudgetCategoryCard(
                      category: cat,
                      budget: budget,
                      spent: spent,
                      settings: settings,
                      onSetBudget: () => _showBudgetDialog(
                          context, provider, settings, cat, budget),
                    );
                  },
                  childCount: expCats.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Future<void> _showBudgetDialog(
    BuildContext context,
    ExpenseProvider provider,
    SettingsProvider settings,
    ExpenseCategory category,
    Budget? existing,
  ) async {
    final ctrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(0) : '');

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(category.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Set Budget',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text(category.name,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13)),
                    ],
                  ),
                ),
                if (existing != null)
                  TextButton(
                    onPressed: () async {
                      await provider.deleteBudget(existing.id!);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Remove',
                        style: TextStyle(color: Color(0xFFFF6B6B))),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: settings.currencySymbol,
                prefixStyle: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
                hintText: '0',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF6C63FF), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(ctrl.text);
                  if (amount == null || amount <= 0) return;

                  await provider.setBudget(Budget(
                    id: existing?.id,
                    categoryId: category.id!,
                    amount: amount,
                    month: provider.selectedMonth,
                    year: provider.selectedYear,
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Budget',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }
}

// ─── Overall Budget Card ──────────────────────────────────────────────────────

class _OverallBudgetCard extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final SettingsProvider settings;

  const _OverallBudgetCard(
      {required this.totalBudget,
      required this.totalSpent,
      required this.settings});

  @override
  Widget build(BuildContext context) {
    final pct = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final remaining = totalBudget - totalSpent;
    final isOver = remaining < 0;
    final progressColor = pct > 0.9
        ? const Color(0xFFEF4444)
        : pct > 0.7
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E3F), Color(0xFF2D1B69)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Budget',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 13)),
              Text(settings.formatAmountFull(totalBudget),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Spent: ${settings.formatAmount(totalSpent)}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 12)),
              Text(
                isOver
                    ? 'Over by ${settings.formatAmount(-remaining)}'
                    : 'Left: ${settings.formatAmount(remaining)}',
                style: TextStyle(
                    color: isOver
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Budget Category Card ─────────────────────────────────────────────────────

class _BudgetCategoryCard extends StatelessWidget {
  final ExpenseCategory category;
  final Budget? budget;
  final double spent;
  final SettingsProvider settings;
  final VoidCallback onSetBudget;

  const _BudgetCategoryCard({
    required this.category,
    required this.budget,
    required this.spent,
    required this.settings,
    required this.onSetBudget,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    final hasBudget = budget != null;
    final pct = hasBudget && budget!.amount > 0
        ? (spent / budget!.amount).clamp(0.0, 1.0)
        : 0.0;
    final isOver = hasBudget && spent > budget!.amount;
    final progressColor = pct > 0.9
        ? const Color(0xFFEF4444)
        : pct > 0.7
            ? const Color(0xFFF59E0B)
            : color;

    return GestureDetector(
      onTap: onSetBudget,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOver
                ? const Color(0xFFEF4444).withOpacity(0.4)
                : Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(category.icon,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text(
                        hasBudget
                            ? '${settings.formatAmount(spent)} of ${settings.formatAmount(budget!.amount)}'
                            : 'Spent: ${settings.formatAmount(spent)} · No budget set',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isOver)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Over!',
                            style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      )
                    else
                      Icon(
                        hasBudget
                            ? Icons.edit_rounded
                            : Icons.add_circle_outline_rounded,
                        color: Colors.white.withOpacity(0.3),
                        size: 18,
                      ),
                    if (hasBudget) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: progressColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (hasBudget) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
