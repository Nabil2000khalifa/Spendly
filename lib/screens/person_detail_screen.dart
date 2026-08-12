import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loan_provider.dart';
import '../providers/settings_provider.dart';
import '../models/loan.dart';
import '../widgets/loan_card.dart';
import 'loan_detail_screen.dart';

class PersonDetailScreen extends StatelessWidget {
  final int personId;
  const PersonDetailScreen({super.key, required this.personId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final settings = context.watch<SettingsProvider>();
    final person = provider.getPersonById(personId);

    if (person == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF12121F),
        appBar: AppBar(backgroundColor: const Color(0xFF12121F)),
        body: const Center(
            child: Text('Person not found',
                style: TextStyle(color: Colors.white))),
      );
    }

    final allLoans = provider.loansForPerson(personId);
    final lentLoans = allLoans.where((l) => l.loan.isLent).toList();
    final borrowedLoans = allLoans.where((l) => l.loan.isBorrowed).toList();
    final netBalance = provider.netBalanceWithPerson(personId);
    final netPositive = netBalance >= 0;

    final totalLent = lentLoans.fold(0.0, (s, l) => s + l.principalAmount);
    final totalBorrowed =
        borrowedLoans.fold(0.0, (s, l) => s + l.principalAmount);
    final totalToReceive = lentLoans
        .where((l) => l.computedStatus != LoanStatus.paid &&
            l.computedStatus != LoanStatus.cancelled)
        .fold(0.0, (s, l) => s + l.balance);
    final totalToPay = borrowedLoans
        .where((l) => l.computedStatus != LoanStatus.paid &&
            l.computedStatus != LoanStatus.cancelled)
        .fold(0.0, (s, l) => s + l.balance);

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ─────────────────────────────────────────
            SliverAppBar(
              backgroundColor: const Color(0xFF12121F),
              elevation: 0,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(person.name),
            ),

            // ── Person header ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    // Avatar + info
                    CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          const Color(0xFF6C63FF).withOpacity(0.2),
                      child: Text(
                        person.initials,
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(person.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    if (person.phone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.phone_rounded,
                              color: Colors.white38, size: 14),
                          const SizedBox(width: 4),
                          Text(person.phone!,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 14)),
                        ],
                      ),
                    ],
                    if (person.email != null) ...[
                      const SizedBox(height: 4),
                      Text(person.email!,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 13)),
                    ],
                    const SizedBox(height: 20),

                    // Net balance card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: netPositive
                              ? [
                                  const Color(0xFF0B3D2E),
                                  const Color(0xFF0F3460)
                                ]
                              : [
                                  const Color(0xFF3D0B0B),
                                  const Color(0xFF3D1F00)
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (netPositive
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFFF6B6B))
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Net Balance with ${person.name}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${netPositive ? '+' : ''}${settings.formatAmountFull(netBalance)}',
                            style: TextStyle(
                              color: netPositive
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFFF6B6B),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            netPositive
                                ? '${person.name} owes you'
                                : 'You owe ${person.name}',
                            style: TextStyle(
                                color: (netPositive
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFFF6B6B))
                                    .withOpacity(0.7),
                                fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                  child: _StatBox(
                                label: 'To Receive',
                                value: settings.formatAmount(totalToReceive),
                                color: const Color(0xFF10B981),
                              )),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _StatBox(
                                label: 'To Pay',
                                value: settings.formatAmount(totalToPay),
                                color: const Color(0xFFFF6B6B),
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Summary stats
                    Row(
                      children: [
                        _SummaryTile(
                          label: 'Total Lent',
                          value: settings.formatAmount(totalLent),
                          icon: Icons.arrow_upward_rounded,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 10),
                        _SummaryTile(
                          label: 'Total Borrowed',
                          value: settings.formatAmount(totalBorrowed),
                          icon: Icons.arrow_downward_rounded,
                          color: const Color(0xFFFF6B6B),
                        ),
                        const SizedBox(width: 10),
                        _SummaryTile(
                          label: 'Transactions',
                          value: '${allLoans.length}',
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFF6C63FF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Loans I gave ─────────────────────────────────────
            if (lentLoans.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Row(
                    children: [
                      Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(2),
                          )),
                      const SizedBox(width: 8),
                      const Text('Money I Lent',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => LoanCard(
                      loanDetails: lentLoans[i],
                      onTap: () => _openDetail(ctx, lentLoans[i]),
                    ),
                    childCount: lentLoans.length,
                  ),
                ),
              ),
            ],

            // ── Loans I took ─────────────────────────────────────
            if (borrowedLoans.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: [
                      Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B),
                            borderRadius: BorderRadius.circular(2),
                          )),
                      const SizedBox(width: 8),
                      const Text('Money I Borrowed',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => LoanCard(
                      loanDetails: borrowedLoans[i],
                      onTap: () => _openDetail(ctx, borrowedLoans[i]),
                    ),
                    childCount: borrowedLoans.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, LoanWithDetails ld) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoanDetailScreen(loanId: ld.loan.id!),
      ),
    );
    context.read<LoanProvider>().loadLoans();
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 10)),
            ],
          ),
        ),
      );
}
