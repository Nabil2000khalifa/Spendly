import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/expense.dart';
import '../models/transfer.dart';
import '../providers/account_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import 'add_account_screen.dart';
import 'add_transfer_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  final int accountId;
  const AccountDetailScreen({super.key, required this.accountId});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  String _dateFilter = 'all'; // 'this_month' | 'last_month' | 'all'

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final settings = context.watch<SettingsProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final account = accountProvider.getAccountById(widget.accountId);

    if (account == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF12121F),
        appBar: AppBar(backgroundColor: const Color(0xFF12121F)),
        body: const Center(
            child: Text('Account not found', style: TextStyle(color: Colors.white))),
      );
    }

    final balance = accountProvider.getBalance(account.id!);
    final allExpenses = expenseProvider.expenses
        .where((e) => e.accountId == account.id)
        .toList();

    // Filter by date
    final now = DateTime.now();
    List<Expense> filteredExpenses = allExpenses;
    if (_dateFilter == 'this_month') {
      filteredExpenses = allExpenses
          .where((e) => e.date.month == now.month && e.date.year == now.year)
          .toList();
    } else if (_dateFilter == 'last_month') {
      final lastM = now.month == 1 ? 12 : now.month - 1;
      final lastY = now.month == 1 ? now.year - 1 : now.year;
      filteredExpenses = allExpenses
          .where((e) => e.date.month == lastM && e.date.year == lastY)
          .toList();
    }

    final totalIncome = filteredExpenses
        .where((e) => e.isIncome)
        .fold(0.0, (s, e) => s + e.amount);
    final totalExpense = filteredExpenses
        .where((e) => e.isExpense)
        .fold(0.0, (s, e) => s + e.amount);

    final color = Color(account.color);

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddAccountScreen(account: account),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Account Header Card ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.3), const Color(0xFF1E1E2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.4), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(account.icon,
                              style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${account.typeDisplayName}${account.accountNumberDisplay.isNotEmpty ? ' · ${account.accountNumberDisplay}' : ''}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (account.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Default',
                              style: TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Current Balance',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    settings.formatAmountFull(balance),
                    style: TextStyle(
                      color: balance >= 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFFF6B6B),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Opening: ${settings.formatAmount(account.openingBalance)}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12),
                      ),
                      if (!account.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Deactivated',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 11)),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Metrics Row ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Income',
                    amount: settings.formatAmount(totalIncome),
                    color: const Color(0xFF10B981),
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: 'Expense',
                    amount: settings.formatAmount(totalExpense),
                    color: const Color(0xFFFF6B6B),
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Action Buttons ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddTransferScreen(initialFromAccount: account),
                      ),
                    ),
                    icon: const Icon(Icons.sync_alt_rounded,
                        color: Colors.white, size: 18),
                    label: const Text('Transfer',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _toggleDeactive(account, accountProvider),
                  icon: Icon(
                    account.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_outline_rounded,
                    color: account.isActive ? Colors.redAccent : Colors.greenAccent,
                    size: 18,
                  ),
                  label: Text(
                    account.isActive ? 'Deactivate' : 'Reactivate',
                    style: TextStyle(
                      color: account.isActive ? Colors.redAccent : Colors.greenAccent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: account.isActive
                          ? Colors.redAccent.withOpacity(0.3)
                          : Colors.greenAccent.withOpacity(0.3),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Transactions Header & Date Filter ───────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Account Transactions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'this_month', label: Text('This M')),
                    ButtonSegment(value: 'last_month', label: Text('Last M')),
                  ],
                  selected: {_dateFilter},
                  onSelectionChanged: (val) =>
                      setState(() => _dateFilter = val.first),
                  style: SegmentedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E2E),
                    selectedBackgroundColor: const Color(0xFF6C63FF),
                    selectedForegroundColor: Colors.white,
                    foregroundColor: Colors.white54,
                    textStyle: const TextStyle(fontSize: 11),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Transaction List ────────────────────────────────
            filteredExpenses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No transactions for this account',
                        style: TextStyle(color: Colors.white.withOpacity(0.4)),
                      ),
                    ),
                  )
                : Column(
                    children: filteredExpenses.map((exp) {
                      final cat = expenseProvider.getCategoryById(exp.categoryId);
                      final isExp = exp.isExpense;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            Text(cat?.icon ?? '📦',
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(exp.title,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14)),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(exp.date),
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isExp ? '-' : '+'}${settings.formatAmount(exp.amount)}',
                              style: TextStyle(
                                color: isExp
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleDeactive(
      Account account, AccountProvider provider) async {
    if (account.isActive) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Deactivate Account?',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Deactivating an account hides it from new transaction pickers while preserving historical transactions.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent),
              child: const Text('Deactivate',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await provider.deactivateAccount(account.id!);
      }
    } else {
      await provider.reactivateAccount(account.id!);
    }
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 10)),
              Text(amount,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
