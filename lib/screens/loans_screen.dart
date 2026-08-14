import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../providers/settings_provider.dart';
import '../models/loan.dart';
import '../widgets/loan_card.dart';
import '../widgets/loan_summary_cards.dart';
import 'add_loan_screen.dart';
import 'loan_detail_screen.dart';
import 'person_detail_screen.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  static const _tabs = [
    ('All Active', 'all', 'active'),
    ('I Lent', 'lent', 'active'),
    ('I Borrowed', 'borrowed', 'active'),
    ('Overdue', 'all', 'overdue'),
    ('Paid', 'all', 'paid'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!mounted) return;
    if (_tabCtrl.indexIsChanging) return;
    final t = _tabs[_tabCtrl.index];
    context.read<LoanProvider>().setFilters(t.$2, t.$3);
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final filtered = provider.filteredLoans;
    final summary = provider.summary;

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Loans & Borrowing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showSearch
                          ? Icons.search_off_rounded
                          : Icons.search_rounded,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() {
                        _showSearch = !_showSearch;
                        if (!_showSearch) {
                          _searchCtrl.clear();
                          provider.setSearch('');
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.people_rounded,
                        color: Colors.white70),
                    onPressed: () => _showPersonsList(context),
                  ),
                ],
              ),
            ),

            // ── Search bar ──────────────────────────────────────
            if (_showSearch)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by person name...',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1E1E2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => provider.setSearch(v),
                ),
              ),

            const SizedBox(height: 12),

            // ── Summary cards ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LoanSummaryCards(summary: summary),
            ),

            const SizedBox(height: 16),

            // ── Tab bar ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  indicator: BoxDecoration(
                    color: const Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(3),
                  tabs: _tabs
                      .map((t) => Tab(
                            height: 34,
                            text: t.$1,
                          ))
                      .toList(),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Loan list ──────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(
                      onAdd: () => _addLoan(context),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final ld = filtered[i];
                        return LoanCard(
                          loanDetails: ld,
                          onTap: () => _openDetail(context, ld),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addLoan(context),
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Loan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _addLoan(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddLoanScreen()),
    );
    if (mounted) context.read<LoanProvider>().loadLoans();
  }

  Future<void> _openDetail(
      BuildContext context, LoanWithDetails ld) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoanDetailScreen(loanId: ld.loan.id!),
      ),
    );
    if (mounted) context.read<LoanProvider>().loadLoans();
  }

  void _showPersonsList(BuildContext context) {
    final provider = context.read<LoanProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('People',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: provider.persons.isEmpty
                  ? Center(
                      child: Text('No people yet',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4))))
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: provider.persons.length,
                      itemBuilder: (_, i) {
                        final p = provider.persons[i];
                        final net = provider.netBalanceWithPerson(p.id!);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFF6C63FF).withOpacity(0.2),
                            child: Text(
                              p.initials,
                              style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(p.name,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(p.phone ?? p.email ?? '',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12)),
                          trailing: Text(
                            '${net >= 0 ? '+' : ''}${context.read<SettingsProvider>().formatAmount(net.abs())}',
                            style: TextStyle(
                              color: net >= 0
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFFF6B6B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PersonDetailScreen(personId: p.id!),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 24).clamp(0.0, double.infinity),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🤝', style: TextStyle(fontSize: 54)),
                  const SizedBox(height: 12),
                  const Text(
                    'No loans yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track money you lend or borrow from friends and family.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add First Loan',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
