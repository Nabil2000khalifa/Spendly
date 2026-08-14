import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../models/loan_ledger_entry.dart';
import '../providers/loan_provider.dart';
import '../providers/settings_provider.dart';
import 'add_loan_screen.dart';
import 'add_payment_screen.dart';
import 'add_interest_screen.dart';

class LoanDetailScreen extends StatefulWidget {
  final int loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  LoanWithDetails? _ld;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() => _loading = true);
    }
    final ld =
        await context.read<LoanProvider>().getLoanDetails(widget.loanId);
    if (mounted) setState(() { _ld = ld; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF12121F),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    if (_ld == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF12121F),
        appBar: AppBar(backgroundColor: const Color(0xFF12121F)),
        body: const Center(
            child: Text('Loan not found', style: TextStyle(color: Colors.white))),
      );
    }

    final ld = _ld!;
    final status = ld.computedStatus;
    final statusColor = ld.statusColor;
    final isLent = ld.loan.isLent;

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(ld.person.name),
        actions: [
          if (status != LoanStatus.paid && status != LoanStatus.cancelled)
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddLoanScreen(loan: ld.loan)),
                );
                _load();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(showLoading: true),
        color: const Color(0xFF6C63FF),
        child: CustomScrollView(
          slivers: [
            // ── Status header ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    // Type + Status row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isLent
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFFF6B6B))
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isLent ? '↑ Money I Lent' : '↓ Money I Borrowed',
                            style: TextStyle(
                              color: isLent
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFFF6B6B),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: statusColor.withOpacity(0.3), width: 1),
                          ),
                          child: Text(
                            ld.statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Financial breakdown card ───────────────────
                    _FinancialBreakdown(ld: ld, settings: settings),
                    const SizedBox(height: 16),

                    // ── Accrued interest banner ────────────────────
                    if (ld.accruedUncommittedInterest > 0.01)
                      _AccruedBanner(
                        ld: ld,
                        settings: settings,
                        onApply: () async {
                          await context
                              .read<LoanProvider>()
                              .applyAccruedInterest(ld);
                          _load();
                        },
                      ),

                    if (ld.accruedUncommittedInterest > 0.01)
                      const SizedBox(height: 16),

                    // ── Action buttons ────────────────────────────
                    if (status != LoanStatus.paid &&
                        status != LoanStatus.cancelled)
                      _ActionButtons(
                        ld: ld,
                        onPayment: () async {
                          final ok = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    AddPaymentScreen(loanDetails: ld)),
                          );
                          if (ok == true) _load();
                        },
                        onInterest: () async {
                          final ok = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    AddInterestScreen(loanDetails: ld)),
                          );
                          if (ok == true) _load();
                        },
                        onAdjustment: () async {
                          final ok = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AddInterestScreen(
                                    loanDetails: ld, isAdjustment: true)),
                          );
                          if (ok == true) _load();
                        },
                        onMarkPaid: () => _markPaid(context),
                        onCancel: () => _cancelLoan(context),
                      ),

                    const SizedBox(height: 24),

                    // ── Notes ─────────────────────────────────────
                    if (ld.loan.notes != null && ld.loan.notes!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notes',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(ld.loan.notes!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Ledger header ─────────────────────────────
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Transaction Ledger',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Ledger entries ──────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final entry = ld.ledger[i];
                    return _LedgerEntry(entry: entry, settings: settings);
                  },
                  childCount: ld.ledger.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markPaid(BuildContext context) async {
    if (_ld == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mark as Fully Paid?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'A final payment of ${context.read<SettingsProvider>().formatAmountFull(_ld!.balance)} will be recorded.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Mark Paid',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<LoanProvider>().markAsPaid(_ld!);
      _load();
    }
  }

  Future<void> _cancelLoan(BuildContext context) async {
    if (_ld == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Loan?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will mark the loan as cancelled. The ledger history will be preserved.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel Loan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<LoanProvider>().cancelLoan(_ld!.loan.id!);
      Navigator.pop(context);
    }
  }
}

// ─── Financial Breakdown Card ─────────────────────────────────────────────────

class _FinancialBreakdown extends StatelessWidget {
  final LoanWithDetails ld;
  final SettingsProvider settings;
  const _FinancialBreakdown({required this.ld, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ld.loan.isLent
              ? [const Color(0xFF0B3D2E), const Color(0xFF12121F)]
              : [const Color(0xFF3D0B0B), const Color(0xFF12121F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (ld.loan.isLent
                  ? const Color(0xFF10B981)
                  : const Color(0xFFFF6B6B))
              .withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          _BreakdownRow(
              label: 'Principal',
              value: settings.formatAmountFull(ld.principalAmount),
              color: Colors.white70),
          if (ld.totalInterestCharged > 0)
            _BreakdownRow(
                label: 'Interest Charged',
                value:
                    '+ ${settings.formatAmountFull(ld.totalInterestCharged)}',
                color: const Color(0xFFF59E0B)),
          const Divider(color: Colors.white12, height: 20),
          _BreakdownRow(
            label: 'Total Amount',
            value: settings.formatAmountFull(ld.totalAmount),
            color: Colors.white,
            bold: true,
          ),
          if (ld.totalPaid > 0) ...[
            _BreakdownRow(
                label: 'Total Paid',
                value: '- ${settings.formatAmountFull(ld.totalPaid)}',
                color: const Color(0xFF10B981)),
            const Divider(color: Colors.white12, height: 20),
            _BreakdownRow(
              label: 'Outstanding',
              value: settings.formatAmountFull(ld.balance),
              color: ld.loan.isLent
                  ? const Color(0xFF10B981)
                  : const Color(0xFFFF6B6B),
              bold: true,
              large: true,
            ),
          ],
          if (ld.totalPaid == 0) ...[
            const Divider(color: Colors.white12, height: 20),
            _BreakdownRow(
              label: 'Outstanding',
              value: settings.formatAmountFull(ld.balance),
              color: ld.loan.isLent
                  ? const Color(0xFF10B981)
                  : const Color(0xFFFF6B6B),
              bold: true,
              large: true,
            ),
          ],
          if (ld.totalPaid > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ld.progressPct,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(ld.statusColor),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(ld.progressPct * 100).toStringAsFixed(1)}% paid',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 11)),
                Text(
                  '${ld.loan.dueDate != null ? 'Due: ${DateFormat('MMM d, yyyy').format(ld.loan.dueDate!)}' : 'Started: ${DateFormat('MMM d, yyyy').format(ld.loan.startDate)}'}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  final bool large;

  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: large ? 14 : 13)),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: large ? 20 : 13,
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );
}

// ─── Accrued Interest Banner ──────────────────────────────────────────────────

class _AccruedBanner extends StatelessWidget {
  final LoanWithDetails ld;
  final SettingsProvider settings;
  final VoidCallback onApply;

  const _AccruedBanner(
      {required this.ld, required this.settings, required this.onApply});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFFF59E0B).withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_rounded,
                color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accrued Interest: ${settings.formatAmountFull(ld.accruedUncommittedInterest)}',
                    style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  Text(
                    '${ld.loan.interestRate}% ${ld.loan.interestPeriod} (not yet committed)',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45), fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onApply,
              child: const Text('Apply',
                  style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}

// ─── Action Buttons Row ───────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final LoanWithDetails ld;
  final VoidCallback onPayment;
  final VoidCallback onInterest;
  final VoidCallback onAdjustment;
  final VoidCallback onMarkPaid;
  final VoidCallback onCancel;

  const _ActionButtons({
    required this.ld,
    required this.onPayment,
    required this.onInterest,
    required this.onAdjustment,
    required this.onMarkPaid,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _ActionBtn(
            icon: Icons.payments_rounded,
            label: 'Record Payment',
            color: const Color(0xFF10B981),
            onTap: onPayment,
          ),
          _ActionBtn(
            icon: Icons.percent_rounded,
            label: 'Add Interest',
            color: const Color(0xFFF59E0B),
            onTap: onInterest,
          ),
          _ActionBtn(
            icon: Icons.tune_rounded,
            label: 'Adjustment',
            color: const Color(0xFF3B82F6),
            onTap: onAdjustment,
          ),
          _ActionBtn(
            icon: Icons.check_circle_rounded,
            label: 'Mark Paid',
            color: const Color(0xFF6C63FF),
            onTap: onMarkPaid,
          ),
          _ActionBtn(
            icon: Icons.cancel_rounded,
            label: 'Cancel',
            color: const Color(0xFFEF4444),
            onTap: onCancel,
          ),
        ],
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ],
          ),
        ),
      );
}

// ─── Ledger Entry Row ─────────────────────────────────────────────────────────

class _LedgerEntry extends StatelessWidget {
  final LoanLedgerEntry entry;
  final SettingsProvider settings;

  const _LedgerEntry({required this.entry, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.entryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: entry.entryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.entryIcon, color: entry.entryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.description,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(entry.entryDate),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 11),
                    ),
                    if (entry.paymentMethod != null) ...[
                      Text(' · ',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3))),
                      Text(
                        PaymentMethod.label(entry.paymentMethod!),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${entry.isPayment ? '-' : '+'}${settings.formatAmountFull(entry.amount)}',
            style: TextStyle(
              color: entry.entryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
