import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../models/loan_ledger_entry.dart';
import '../models/account.dart';
import '../providers/loan_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/account_provider.dart';

class AddPaymentScreen extends StatefulWidget {
  final LoanWithDetails loanDetails;
  const AddPaymentScreen({super.key, required this.loanDetails});

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _method = PaymentMethod.cash;
  DateTime _date = DateTime.now();
  Account? _selectedAccount;

  LoanWithDetails get ld => widget.loanDetails;

  double get _inputAmount => double.tryParse(_amountCtrl.text) ?? 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedAccount == null) {
      final accountProvider = context.watch<AccountProvider>();
      if (ld.loan.accountId != null) {
        _selectedAccount = accountProvider.getAccountById(ld.loan.accountId);
      }
      _selectedAccount ??= accountProvider.defaultAccount ??
          (accountProvider.activeAccounts.isNotEmpty
              ? accountProvider.activeAccounts.first
              : null);
    }
  }

  /// Simulates interest-first allocation for the preview
  _Allocation _allocate(double payment) {
    final toInterest = payment.clamp(0.0, ld.outstandingInterest);
    final toPrincipal = (payment - toInterest).clamp(0.0, ld.principalAmount);
    return _Allocation(toInterest: toInterest, toPrincipal: toPrincipal);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final alloc = _allocate(_inputAmount);

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Record Payment'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Loan summary ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(ld.person.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ld.loan.isLent
                            ? const Color(0xFF10B981).withOpacity(0.15)
                            : const Color(0xFFFF6B6B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ld.loan.isLent ? '↑ Lent' : '↓ Borrowed',
                        style: TextStyle(
                          color: ld.loan.isLent
                              ? const Color(0xFF10B981)
                              : const Color(0xFFFF6B6B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _InfoPill(
                        label: 'Principal',
                        value: settings.formatAmount(ld.principalAmount),
                        color: Colors.white70),
                    const SizedBox(width: 8),
                    if (ld.totalInterestCharged > 0)
                      _InfoPill(
                          label: 'Interest',
                          value: settings
                              .formatAmount(ld.outstandingInterest),
                          color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    _InfoPill(
                        label: 'Outstanding',
                        value: settings.formatAmount(ld.balance),
                        color: const Color(0xFF6C63FF),
                        bold: true),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Amount ──────────────────────────────────────────
          Text('Payment Amount',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 13)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountCtrl,
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
              hintText: '0.00',
              hintStyle:
                  TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 28),
              filled: true,
              fillColor: const Color(0xFF1E1E2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (_) => setState(() {}),
          ),

          // ── Quick fill buttons ───────────────────────────────
          const SizedBox(height: 10),
          Row(
            children: [
              _QuickBtn(
                  label: 'Full',
                  onTap: () => setState(() =>
                      _amountCtrl.text =
                          ld.balance.toStringAsFixed(2))),
              const SizedBox(width: 8),
              _QuickBtn(
                  label: '½',
                  onTap: () => setState(() =>
                      _amountCtrl.text =
                          (ld.balance / 2).toStringAsFixed(2))),
              const SizedBox(width: 8),
              _QuickBtn(
                  label: '¼',
                  onTap: () => setState(() =>
                      _amountCtrl.text =
                          (ld.balance / 4).toStringAsFixed(2))),
            ],
          ),

          const SizedBox(height: 20),

          // ── Allocation preview ───────────────────────────────
          if (_inputAmount > 0 && ld.outstandingInterest > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Color(0xFFF59E0B), size: 14),
                      SizedBox(width: 6),
                      Text('Payment Allocation (Interest First)',
                          style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('→ To Interest',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12)),
                      Text(settings.formatAmountFull(alloc.toInterest),
                          style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                  if (alloc.toPrincipal > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('→ To Principal',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12)),
                        Text(settings.formatAmountFull(alloc.toPrincipal),
                            style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 20),

          // ── Payment method ───────────────────────────────────
          Text('Payment Method',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PaymentMethod.all.map((m) {
              final selected = m == _method;
              return GestureDetector(
                onTap: () => setState(() => _method = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF6C63FF).withOpacity(0.2)
                        : const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF6C63FF).withOpacity(0.5)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PaymentMethod.icon(m),
                          color: selected
                              ? const Color(0xFF6C63FF)
                              : Colors.white38,
                          size: 18),
                      const SizedBox(width: 6),
                      Text(
                        PaymentMethod.label(m),
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF6C63FF)
                              : Colors.white54,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── Payment Account ─────────────────────────────────
          Text('Account',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Account>(
                value: _selectedAccount,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E1E2E),
                style: const TextStyle(color: Colors.white),
                items: context.watch<AccountProvider>().activeAccounts.map((acc) {
                  return DropdownMenuItem(
                    value: acc,
                    child: Row(
                      children: [
                        Text(acc.icon, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(acc.name)),
                        if (acc.isDefault)
                          Text(' (Default)',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedAccount = val),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Date ────────────────────────────────────────────
          Text('Date',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 13)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF6C63FF),
                        surface: Color(0xFF1E1E2E)),
                  ),
                  child: child!,
                ),
              );
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withOpacity(0.08), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: Color(0xFF6C63FF), size: 20),
                  const SizedBox(width: 12),
                  Text(DateFormat('EEEE, MMM d, yyyy').format(_date),
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Note ────────────────────────────────────────────
          Text('Note (optional)',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add a note...',
              hintStyle:
                  TextStyle(color: Colors.white.withOpacity(0.25)),
              filled: true,
              fillColor: const Color(0xFF1E1E2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _inputAmount > 0 ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _inputAmount > 0
                    ? 'Record ${settings.formatAmountFull(_inputAmount)} Payment'
                    : 'Enter Amount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amount = _inputAmount;
    if (amount <= 0) return;

    if (amount > ld.balance + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment exceeds outstanding balance (${context.read<SettingsProvider>().formatAmountFull(ld.balance)})'),
        ),
      );
      return;
    }

    await context.read<LoanProvider>().recordPayment(
          loanDetails: ld,
          amount: amount,
          method: _method,
          date: _date,
          accountId: _selectedAccount?.id,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );

    await context.read<AccountProvider>().loadAccounts();

    if (mounted) Navigator.pop(context, true);
  }
}

class _Allocation {
  final double toInterest;
  final double toPrincipal;
  _Allocation({required this.toInterest, required this.toPrincipal});
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _InfoPill(
      {required this.label,
      required this.value,
      required this.color,
      this.bold = false});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 10)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ],
      );
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
      );
}
