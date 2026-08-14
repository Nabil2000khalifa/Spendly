import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/account_transaction_item.dart';
import '../providers/account_provider.dart';
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
  String _typeFilter = 'all'; // 'all' | 'expense' | 'income' | 'transfer' | 'loan'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  Map<String, double>? _metrics;
  List<AccountTransactionItem>? _transactions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reload();
    });
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final provider = context.read<AccountProvider>();
    final metrics = await provider.getAccountMetrics(widget.accountId);
    final txs = await provider.getUnifiedTransactions(widget.accountId);
    
    if (mounted) {
      setState(() {
        _metrics = metrics;
        _transactions = txs;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleDeactive(Account account, AccountProvider provider) async {
    final hasTx = await provider.hasTransactions(account.id!);
    if (!mounted) return;

    if (account.isActive && hasTx) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Deactivate Account', style: TextStyle(color: Colors.white)),
          content: const Text(
            'This account has transaction history. Deactivating will hide it from new transaction pickers, but preserve all past transactions and statistics.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(ctx);
                await provider.deactivateAccount(account.id!);
                await _reload();
              },
              child: const Text('Deactivate', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      if (account.isActive) {
        await provider.deactivateAccount(account.id!);
      } else {
        await provider.reactivateAccount(account.id!);
      }
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final settings = context.watch<SettingsProvider>();
    final account = accountProvider.getAccountById(widget.accountId);

    if (account == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF12121F),
        appBar: AppBar(backgroundColor: const Color(0xFF12121F)),
        body: const Center(
          child: Text('Account not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final balance = accountProvider.getBalance(account.id!);
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
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddAccountScreen(account: account),
                ),
              );
              await _reload();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading || _metrics == null || _transactions == null
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
            : Builder(
                builder: (context) {
                  final now = DateTime.now();

                  // Filter items by date
                  List<AccountTransactionItem> items = _transactions!;
            if (_dateFilter == 'this_month') {
              items = items
                  .where((e) => e.date.month == now.month && e.date.year == now.year)
                  .toList();
            } else if (_dateFilter == 'last_month') {
              final lastM = now.month == 1 ? 12 : now.month - 1;
              final lastY = now.month == 1 ? now.year - 1 : now.year;
              items = items
                  .where((e) => e.date.month == lastM && e.date.year == lastY)
                  .toList();
            }

            // Filter items by type
            if (_typeFilter == 'expense') {
              items = items.where((e) => e.itemType == 'expense').toList();
            } else if (_typeFilter == 'income') {
              items = items.where((e) => e.itemType == 'income').toList();
            } else if (_typeFilter == 'transfer') {
              items = items
                  .where((e) => e.itemType == 'transfer_in' || e.itemType == 'transfer_out')
                  .toList();
            } else if (_typeFilter == 'loan') {
              items = items.where((e) => e.itemType == 'loan').toList();
            }

            // Filter by search query
            if (_searchQuery.trim().isNotEmpty) {
              final q = _searchQuery.trim().toLowerCase();
              items = items.where((e) {
                final matchTitle = e.title.toLowerCase().contains(q);
                final matchSub = e.subtitle.toLowerCase().contains(q);
                final matchNote = (e.note ?? '').toLowerCase().contains(q);
                return matchTitle || matchSub || matchNote;
              }).toList();
            }

            return ListView(
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
                              child: Text(account.icon, style: const TextStyle(fontSize: 24)),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Current Balance',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.formatAmountFull(balance),
                        style: TextStyle(
                          color: balance >= 0 ? const Color(0xFF10B981) : const Color(0xFFFF6B6B),
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
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                          if (!account.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Deactivated',
                                style: TextStyle(color: Colors.redAccent, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Metrics Grid ────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Income',
                        amount: settings.formatAmount(_metrics!['income'] ?? 0.0),
                        color: const Color(0xFF10B981),
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        label: 'Expense',
                        amount: settings.formatAmount(_metrics!['expense'] ?? 0.0),
                        color: const Color(0xFFFF6B6B),
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Transfers In',
                        amount: settings.formatAmount(_metrics!['transfersIn'] ?? 0.0),
                        color: const Color(0xFF06B6D4),
                        icon: Icons.south_west_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        label: 'Transfers Out',
                        amount: settings.formatAmount(_metrics!['transfersOut'] ?? 0.0),
                        color: const Color(0xFFF59E0B),
                        icon: Icons.north_east_rounded,
                      ),
                    ),
                  ],
                ),
                if ((_metrics!['loansLent'] ?? 0) > 0 || (_metrics!['loansBorrowed'] ?? 0) > 0 || (_metrics!['loanRepayments'] ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if ((_metrics!['loansLent'] ?? 0) > 0)
                        Expanded(
                          child: _MetricTile(
                            label: 'Loans Lent',
                            amount: settings.formatAmount(_metrics!['loansLent'] ?? 0.0),
                            color: const Color(0xFFE84393), // Pink-ish
                            icon: Icons.upload_rounded,
                          ),
                        ),
                      if ((_metrics!['loansLent'] ?? 0) > 0) const SizedBox(width: 8),
                      if ((_metrics!['loansBorrowed'] ?? 0) > 0)
                        Expanded(
                          child: _MetricTile(
                            label: 'Loans Borrowed',
                            amount: settings.formatAmount(_metrics!['loansBorrowed'] ?? 0.0),
                            color: const Color(0xFF6C5CE7), // Purple-ish
                            icon: Icons.download_rounded,
                          ),
                        ),
                      if ((_metrics!['loansBorrowed'] ?? 0) > 0) const SizedBox(width: 8),
                      if ((_metrics!['loanRepayments'] ?? 0) > 0)
                        Expanded(
                          child: _MetricTile(
                            label: 'Repayments',
                            amount: settings.formatAmount(_metrics!['loanRepayments'] ?? 0.0),
                            color: const Color(0xFF00B894), // Teal-ish
                            icon: Icons.autorenew_rounded,
                          ),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // ── Actions ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddTransferScreen(initialFromAccount: account),
                            ),
                          );
                          await _reload();
                        },
                        icon: const Icon(Icons.sync_alt_rounded, color: Colors.white, size: 18),
                        label: const Text('Transfer', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _toggleDeactive(account, accountProvider),
                      icon: Icon(
                        account.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Search Bar ─────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search transactions...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.4), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Type Filter Chips ────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _typeFilter == 'all',
                        onTap: () => setState(() => _typeFilter = 'all'),
                      ),
                      _FilterChip(
                        label: 'Expenses',
                        selected: _typeFilter == 'expense',
                        onTap: () => setState(() => _typeFilter = 'expense'),
                      ),
                      _FilterChip(
                        label: 'Income',
                        selected: _typeFilter == 'income',
                        onTap: () => setState(() => _typeFilter = 'income'),
                      ),
                      _FilterChip(
                        label: 'Transfers',
                        selected: _typeFilter == 'transfer',
                        onTap: () => setState(() => _typeFilter = 'transfer'),
                      ),
                      _FilterChip(
                        label: 'Loans',
                        selected: _typeFilter == 'loan',
                        onTap: () => setState(() => _typeFilter = 'loan'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'History (${items.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'this_month', label: Text('This M')),
                        ButtonSegment(value: 'last_month', label: Text('Last M')),
                      ],
                      selected: {_dateFilter},
                      onSelectionChanged: (val) => setState(() => _dateFilter = val.first),
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
                items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No matching transactions',
                            style: TextStyle(color: Colors.white.withOpacity(0.4)),
                          ),
                        ),
                      )
                    : Column(
                        children: items.map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E2E),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Row(
                              children: [
                                Text(item.icon, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        '${item.subtitle} · ${DateFormat('MMM d, yyyy').format(item.date)}',
                                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${item.isPositive ? '+' : '-'}${settings.formatAmount(item.amount)}',
                                  style: TextStyle(
                                    color: item.isPositive ? const Color(0xFF10B981) : const Color(0xFFFF6B6B),
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
            );
          },
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    amount,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6C63FF).withOpacity(0.25) : const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF6C63FF) : Colors.white60,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
