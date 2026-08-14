import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/account_provider.dart';
import '../models/expense.dart';
import '../widgets/expense_card.dart';
import '../widgets/summary_card.dart';
import 'add_expense_screen.dart';
import 'accounts_screen.dart';
import 'account_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final accountProvider = context.watch<AccountProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expense Manager',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${_months[provider.selectedMonth - 1]} ${provider.selectedYear}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    _MonthSelector(
                      month: provider.selectedMonth,
                      year: provider.selectedYear,
                      onChanged: (m, y) => provider.setMonth(m, y),
                    ),
                  ],
                ),
              ),
            ),

            // ── Balance Card ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BalanceCard(
                  balance: settings.formatAmountFull(accountProvider.totalBalance),
                  income: settings.formatAmount(provider.totalIncome),
                  expense: settings.formatAmount(provider.totalExpenses),
                  currencyCode: settings.currency,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Accounts Summary Section ─────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Accounts',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AccountsScreen(),
                            ),
                          ),
                          child: const Text(
                            'Manage',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 72,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: accountProvider.activeAccounts.length,
                        itemBuilder: (ctx, idx) {
                          final acc = accountProvider.activeAccounts[idx];
                          final bal = accountProvider.getBalance(acc.id!);
                          final color = Color(acc.color);
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AccountDetailScreen(accountId: acc.id!),
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E2E),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: acc.isDefault
                                      ? const Color(0xFF6C63FF).withOpacity(0.5)
                                      : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(acc.icon,
                                          style: const TextStyle(fontSize: 18)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        acc.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        settings.formatAmount(bal),
                                        style: TextStyle(
                                          color: bal >= 0
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFFF6B6B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Quick Stats Row ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        label: 'Transactions',
                        amount: '${provider.expenses.length}',
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFF6C63FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        label: 'Avg / Day',
                        amount: settings.formatAmount(
                          provider.totalExpenses > 0
                              ? provider.totalExpenses / 30
                              : 0,
                        ),
                        icon: Icons.trending_down_rounded,
                        color: const Color(0xFFFF6B6B),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Transactions Header ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Transactions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${provider.expenses.length} records',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Expense List ────────────────────────────────
            provider.expenses.isEmpty
                ? SliverToBoxAdapter(child: _EmptyState())
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final expense = provider.expenses[index];
                          return ExpenseCard(
                            expense: expense,
                            onTap: () => _editExpense(context, expense),
                            onDelete: () async {
                              await provider.deleteExpense(expense.id!);
                              if (context.mounted) {
                                await context.read<AccountProvider>().loadAccounts();
                              }
                            },
                          );
                        },
                        childCount: provider.expenses.length,
                      ),
                    ),
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: _AddFAB(
        onExpense: () => _addNew(context, 'expense'),
        onIncome: () => _addNew(context, 'income'),
      ),
    );
  }

  Future<void> _addNew(BuildContext context, String type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(initialType: type),
      ),
    );
    if (mounted) {
      context.read<ExpenseProvider>().loadExpenses();
      context.read<AccountProvider>().loadAccounts();
    }
  }

  Future<void> _editExpense(BuildContext context, Expense expense) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(expense: expense),
      ),
    );
    if (mounted) {
      context.read<ExpenseProvider>().loadExpenses();
      context.read<AccountProvider>().loadAccounts();
    }
  }
}

// ─── Month Selector Widget ──────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final int month;
  final int year;
  final void Function(int month, int year) onChanged;

  const _MonthSelector({
    required this.month,
    required this.year,
    required this.onChanged,
  });

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ArrowBtn(
          icon: Icons.chevron_left_rounded,
          onTap: () {
            int m = month - 1, y = year;
            if (m < 1) { m = 12; y--; }
            onChanged(m, y);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '${_months[month - 1]} $year',
            style: const TextStyle(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
        _ArrowBtn(
          icon: Icons.chevron_right_rounded,
          onTap: () {
            int m = month + 1, y = year;
            if (m > 12) { m = 1; y++; }
            onChanged(m, y);
          },
        ),
      ],
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// ─── Empty State ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Text('💸', style: const TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first expense',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── FAB with menu ──────────────────────────────────────────────────────────

class _AddFAB extends StatefulWidget {
  final VoidCallback onExpense;
  final VoidCallback onIncome;
  const _AddFAB({required this.onExpense, required this.onIncome});

  @override
  State<_AddFAB> createState() => _AddFABState();
}

class _AddFABState extends State<_AddFAB>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _rotation = Tween(begin: 0.0, end: 0.375).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          _MiniAction(
            label: 'Add Income',
            icon: Icons.add_circle_outline_rounded,
            color: const Color(0xFF10B981),
            onTap: () { _toggle(); widget.onIncome(); },
          ),
          const SizedBox(height: 10),
          _MiniAction(
            label: 'Add Expense',
            icon: Icons.remove_circle_outline_rounded,
            color: const Color(0xFFFF6B6B),
            onTap: () { _toggle(); widget.onExpense(); },
          ),
          const SizedBox(height: 10),
        ],
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: const Color(0xFF6C63FF),
          elevation: 6,
          child: RotationTransition(
            turns: _rotation,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MiniAction(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: color.withOpacity(0.3), width: 1),
            ),
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4), width: 1),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ],
      ),
    );
  }
}
