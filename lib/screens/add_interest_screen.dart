import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../providers/loan_provider.dart';
import '../providers/settings_provider.dart';

class AddInterestScreen extends StatefulWidget {
  final LoanWithDetails loanDetails;
  final bool isAdjustment;

  const AddInterestScreen({
    super.key,
    required this.loanDetails,
    this.isAdjustment = false,
  });

  @override
  State<AddInterestScreen> createState() => _AddInterestScreenState();
}

class _AddInterestScreenState extends State<AddInterestScreen> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  LoanWithDetails get ld => widget.loanDetails;

  @override
  void initState() {
    super.initState();
    // Pre-fill accrued interest if available
    final accrued = ld.accruedUncommittedInterest;
    if (!widget.isAdjustment && accrued > 0) {
      _amountCtrl.text = accrued.toStringAsFixed(2);
      _reasonCtrl.text =
          '${ld.loan.interestPeriod == 'monthly' ? 'Monthly' : 'Yearly'} ${ld.loan.interestRate}% interest';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isAdj = widget.isAdjustment;
    final accrued = ld.accruedUncommittedInterest;

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isAdj ? 'Add Adjustment' : 'Add Interest'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Context card ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF6C63FF).withOpacity(0.2),
                  child: Text(ld.person.initials,
                      style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ld.person.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text(
                        'Current balance: ${settings.formatAmountFull(ld.balance)}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Accrued interest banner ──────────────────────────
          if (!isAdj && accrued > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_rounded,
                      color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${settings.formatAmountFull(accrued)} in accrued '
                      '${ld.loan.interestPeriod} interest (not yet recorded)',
                      style: const TextStyle(
                          color: Color(0xFFF59E0B), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Amount ──────────────────────────────────────────
          Text(isAdj ? 'Adjustment Amount' : 'Interest Amount',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            autofocus: !(!isAdj && accrued > 0),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: settings.currencySymbol,
              prefixStyle: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 26,
                  fontWeight: FontWeight.bold),
              hintText: '0.00',
              hintStyle:
                  TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 26),
              filled: true,
              fillColor: const Color(0xFF1E1E2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 20),

          // ── Description ─────────────────────────────────────
          Text('Description / Reason',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: isAdj
                  ? 'e.g. Delayed repayment penalty'
                  : 'e.g. Monthly 2% interest - August 2026',
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

          // ── Info box ─────────────────────────────────────────
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    color: Colors.white.withOpacity(0.3), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This will create an immutable ledger entry. '
                    'Historical records cannot be deleted.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: isAdj
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                isAdj ? 'Add Adjustment' : 'Add Interest Entry',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    final desc = _reasonCtrl.text.trim().isEmpty
        ? (widget.isAdjustment ? 'Manual adjustment' : 'Interest charge')
        : _reasonCtrl.text.trim();

    final provider = context.read<LoanProvider>();
    if (widget.isAdjustment) {
      await provider.addAdjustmentEntry(
        loanId: ld.loan.id!,
        amount: amount,
        description: desc,
        date: _date,
      );
    } else {
      await provider.addInterestEntry(
        loanId: ld.loan.id!,
        amount: amount,
        description: desc,
        date: _date,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }
}
