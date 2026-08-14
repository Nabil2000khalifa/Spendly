import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/account_provider.dart';
import '../models/account.dart';
import '../widgets/chart_widgets.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<int, double> _categoryData = {};
  List<Map<String, dynamic>> _monthlyData = [];
  bool _loading = true;
  int? _lastMonth;
  int? _lastYear;
  int? _selectedAccountId; // null = All Accounts
  Object? _lastExpensesRef;

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<ExpenseProvider>();
    if (_lastMonth != provider.selectedMonth ||
        _lastYear != provider.selectedYear ||
        _lastExpensesRef != provider.expenses) {
      _lastMonth = provider.selectedMonth;
      _lastYear = provider.selectedYear;
      _lastExpensesRef = provider.expenses;
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_categoryData.isEmpty && _monthlyData.isEmpty) {
      if (mounted) setState(() => _loading = true);
    }
    final provider = context.read<ExpenseProvider>();
    final targetMonth = provider.selectedMonth;
    final targetYear = provider.selectedYear;

    final cat = await provider.getCategoryBreakdown(accountId: _selectedAccountId);
    final monthly = await provider.getMonthlyTotals(accountId: _selectedAccountId);

    if (mounted &&
        provider.selectedMonth == targetMonth &&
        provider.selectedYear == targetYear) {
      setState(() {
        _categoryData = cat;
        _monthlyData = monthly;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final accountProvider = context.watch<AccountProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header & Account Filter ────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statistics',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedAccountId,
                        dropdownColor: const Color(0xFF1E1E2E),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Accounts'),
                          ),
                          ...accountProvider.allAccounts.map((acc) {
                            return DropdownMenuItem<int?>(
                              value: acc.id,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(acc.icon,
                                      style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(acc.name),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedAccountId = val;
                          });
                          _loadData();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Tab Bar ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  indicator: BoxDecoration(
                    color: const Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(4),
                  tabs: const [
                    Tab(text: 'By Category'),
                    Tab(text: 'Monthly Trend'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Tab Views ───────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C63FF)))
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        // ── Pie chart tab ──
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              _SectionCard(
                                title: 'Spending by Category',
                                child: CategoryPieChart(
                                  data: _categoryData,
                                  categories: provider.categories,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _SectionCard(
                                title: 'Category Breakdown',
                                child: _CategoryList(
                                  data: _categoryData,
                                  provider: provider,
                                  settings: settings,
                                ),
                              ),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),

                        // ── Bar chart tab ──
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              _SectionCard(
                                title: 'Last 6 Months',
                                child: MonthlyBarChart(data: _monthlyData),
                              ),
                              const SizedBox(height: 16),
                              _SectionCard(
                                title: 'Monthly Summary',
                                child: _MonthlyList(
                                  data: _monthlyData,
                                  settings: settings,
                                ),
                              ),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Category List ───────────────────────────────────────────────────────────

class _CategoryList extends StatelessWidget {
  final Map<int, double> data;
  final ExpenseProvider provider;
  final SettingsProvider settings;

  const _CategoryList(
      {required this.data, required this.provider, required this.settings});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Text('No data', style: TextStyle(color: Colors.white38));
    }

    final total = data.values.fold(0.0, (a, b) => a + b);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sorted.map((entry) {
        final cat = provider.getCategoryById(entry.key);
        final pct = total > 0 ? entry.value / total : 0.0;
        final color = cat != null ? Color(cat.color) : const Color(0xFF6B7280);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Text(cat?.icon ?? '📦',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cat?.name ?? 'Unknown',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ),
                  Text(
                    settings.formatAmountFull(entry.value),
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Monthly List ─────────────────────────────────────────────────────────────

class _MonthlyList extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final SettingsProvider settings;

  const _MonthlyList({required this.data, required this.settings});

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: data.reversed.map((d) {
        final income = d['income'] as double;
        final expense = d['expense'] as double;
        final net = income - expense;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _months[d['month'] as int],
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_months[d['month'] as int]} ${d['year']}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Income ${settings.formatAmount(income)} · Spent ${settings.formatAmount(expense)}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                (net >= 0 ? '+' : '') + settings.formatAmount(net),
                style: TextStyle(
                  color: net >= 0
                      ? const Color(0xFF10B981)
                      : const Color(0xFFFF6B6B),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
