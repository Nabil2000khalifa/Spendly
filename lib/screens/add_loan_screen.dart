import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../models/person.dart';
import '../models/account.dart';
import '../providers/loan_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/account_provider.dart';

class AddLoanScreen extends StatefulWidget {
  final Loan? loan; // null = create, non-null = edit
  const AddLoanScreen({super.key, this.loan});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _fixedInterestCtrl = TextEditingController();

  String _type = 'lent';
  Person? _selectedPerson;
  Account? _selectedAccount;
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;
  bool _hasDueDate = false;
  bool _interestEnabled = false;
  String _interestType = 'percentage';
  String _interestPeriod = 'one_time';

  bool get _isEditing => widget.loan != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final l = widget.loan!;
      _type = l.type;
      _amountCtrl.text = l.principalAmount.toStringAsFixed(2);
      _noteCtrl.text = l.notes ?? '';
      _startDate = l.startDate;
      _dueDate = l.dueDate;
      _hasDueDate = l.dueDate != null;
      _interestEnabled = l.interestEnabled;
      _interestType = l.interestType;
      _interestPeriod = l.interestPeriod;
      _rateCtrl.text = l.interestRate > 0 ? l.interestRate.toString() : '';
      _fixedInterestCtrl.text =
          l.interestType == 'fixed' && l.interestRate > 0
              ? l.interestRate.toString()
              : '';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accountProvider = context.watch<AccountProvider>();

    if (_isEditing && _selectedPerson == null) {
      final persons = context.read<LoanProvider>().persons;
      try {
        _selectedPerson =
            persons.firstWhere((p) => p.id == widget.loan!.personId);
      } catch (_) {}
    } else if (_selectedPerson == null) {
      final persons = context.read<LoanProvider>().persons;
      if (persons.isNotEmpty) _selectedPerson = persons.first;
    }

    if (_selectedAccount == null) {
      if (_isEditing && widget.loan!.accountId != null) {
        _selectedAccount =
            accountProvider.getAccountById(widget.loan!.accountId);
      }
      _selectedAccount ??= accountProvider.defaultAccount ??
          (accountProvider.activeAccounts.isNotEmpty
              ? accountProvider.activeAccounts.first
              : null);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _rateCtrl.dispose();
    _fixedInterestCtrl.dispose();
    super.dispose();
  }

  double get _principal => double.tryParse(_amountCtrl.text) ?? 0;

  double get _interestPreview {
    if (!_interestEnabled) return 0;
    if (_interestType == 'fixed') {
      return double.tryParse(_fixedInterestCtrl.text) ?? 0;
    }
    if (_interestPeriod == 'one_time') {
      final rate = double.tryParse(_rateCtrl.text) ?? 0;
      return _principal * rate / 100;
    }
    return 0; // Recurring — shown separately
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<LoanProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Edit Loan' : 'New Loan'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Type toggle ────────────────────────────────────
            _SectionLabel('Transaction Type'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _TypeBtn(
                    label: 'I Lent Money',
                    icon: '↑',
                    isSelected: _type == 'lent',
                    color: const Color(0xFF10B981),
                    onTap: () => setState(() => _type = 'lent'),
                  ),
                  _TypeBtn(
                    label: 'I Borrowed',
                    icon: '↓',
                    isSelected: _type == 'borrowed',
                    color: const Color(0xFFFF6B6B),
                    onTap: () => setState(() => _type = 'borrowed'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Person ─────────────────────────────────────────
            _SectionLabel('Person'),
            const SizedBox(height: 8),
            _PersonSelector(
              persons: provider.persons,
              selected: _selectedPerson,
              onSelect: (p) => setState(() => _selectedPerson = p),
              onAddNew: () => _addNewPerson(context),
            ),
            const SizedBox(height: 20),

            // ── Amount ─────────────────────────────────────────
            _SectionLabel('Principal Amount'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              decoration: _inputDeco(
                  hint: '0.00', prefix: settings.currencySymbol),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                if ((double.tryParse(v) ?? 0) <= 0) return 'Must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Account ─────────────────────────────────────────
            _SectionLabel('Disbursement Account'),
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

            // ── Start date ─────────────────────────────────────
            _SectionLabel('Date'),
            const SizedBox(height: 8),
            _DatePickerField(
              date: _startDate,
              onPick: (d) => setState(() => _startDate = d),
              label: 'Start Date',
            ),
            const SizedBox(height: 16),

            // ── Due date ───────────────────────────────────────
            Row(
              children: [
                Switch(
                  value: _hasDueDate,
                  onChanged: (v) =>
                      setState(() {
                        _hasDueDate = v;
                        if (!v) _dueDate = null;
                      }),
                  activeColor: const Color(0xFF6C63FF),
                ),
                const SizedBox(width: 8),
                const Text('Set Due Date',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
            if (_hasDueDate) ...[
              const SizedBox(height: 8),
              _DatePickerField(
                date: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                onPick: (d) => setState(() => _dueDate = d),
                label: 'Due Date',
              ),
            ],
            const SizedBox(height: 20),

            // ── Interest ───────────────────────────────────────
            _SectionLabel('Interest'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withOpacity(0.06), width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Switch(
                        value: _interestEnabled,
                        onChanged: (v) =>
                            setState(() => _interestEnabled = v),
                        activeColor: const Color(0xFF6C63FF),
                      ),
                      const SizedBox(width: 8),
                      const Text('Enable Interest',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                  if (_interestEnabled) ...[
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 8),
                    // Interest type
                    Row(
                      children: [
                        _InterestTypeChip(
                          label: '% Percentage',
                          selected: _interestType == 'percentage',
                          onTap: () =>
                              setState(() => _interestType = 'percentage'),
                        ),
                        const SizedBox(width: 8),
                        _InterestTypeChip(
                          label: 'Fixed Amount',
                          selected: _interestType == 'fixed',
                          onTap: () =>
                              setState(() => _interestType = 'fixed'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_interestType == 'percentage') ...[
                      // Rate input
                      TextFormField(
                        controller: _rateCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco(hint: 'e.g. 5', suffix: '%'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      // Period
                      const Text('Calculation Period',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ('one_time', 'One-time'),
                          ('monthly', 'Monthly'),
                          ('yearly', 'Yearly'),
                        ]
                            .map((p) => _PeriodChip(
                                  label: p.$2,
                                  selected: _interestPeriod == p.$1,
                                  onTap: () =>
                                      setState(() => _interestPeriod = p.$1),
                                ))
                            .toList(),
                      ),
                    ] else ...[
                      // Fixed amount input
                      TextFormField(
                        controller: _fixedInterestCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco(
                            hint: 'Fixed interest amount',
                            prefix: settings.currencySymbol),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Notes ──────────────────────────────────────────
            _SectionLabel('Notes (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _inputDeco(hint: 'e.g. Borrowed for laptop purchase'),
            ),
            const SizedBox(height: 24),

            // ── Preview ────────────────────────────────────────
            if (_principal > 0) _LoanPreview(
              principal: _principal,
              interestAmount: _interestPreview,
              isRecurring: _interestEnabled &&
                  _interestType == 'percentage' &&
                  _interestPeriod != 'one_time',
              interestPeriod: _interestPeriod,
              interestRate: double.tryParse(_rateCtrl.text) ?? 0,
              settings: settings,
            ),

            const SizedBox(height: 24),

            // ── Save ───────────────────────────────────────────
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'lent'
                      ? const Color(0xFF10B981)
                      : const Color(0xFFFF6B6B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _isEditing
                      ? 'Update Loan'
                      : (_type == 'lent' ? 'Record Lending' : 'Record Borrowing'),
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
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPerson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a person')),
      );
      return;
    }

    final provider = context.read<LoanProvider>();
    final principal = double.parse(_amountCtrl.text.trim());
    final principalPaise = (principal * 100).round();
    final now = DateTime.now();

    double rate = 0;
    String intType = _interestType;
    String intPeriod = _interestPeriod;
    if (_interestEnabled) {
      if (_interestType == 'percentage') {
        rate = double.tryParse(_rateCtrl.text) ?? 0;
      } else {
        rate = double.tryParse(_fixedInterestCtrl.text) ?? 0;
        intPeriod = 'one_time';
      }
    }

    final loan = Loan(
      id: widget.loan?.id,
      personId: _selectedPerson!.id!,
      accountId: _selectedAccount?.id,
      type: _type,
      principalPaise: principalPaise,
      interestEnabled: _interestEnabled,
      interestType: intType,
      interestRate: rate,
      interestPeriod: intPeriod,
      startDate: _startDate,
      dueDate: _hasDueDate ? _dueDate : null,
      status: LoanStatus.active,
      notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: widget.loan?.createdAt ?? now,
      updatedAt: now,
    );

    if (_isEditing) {
      await provider.updateLoan(loan);
    } else {
      await provider.addLoan(loan);
    }

    await context.read<AccountProvider>().loadAccounts();

    if (mounted) Navigator.pop(context);
  }

  Future<void> _addNewPerson(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final person = await showDialog<Person>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Person',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Full name *',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Phone (optional)',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                Person(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  createdAt: DateTime.now(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (person != null && mounted) {
      final provider = context.read<LoanProvider>();
      final saved = await provider.addPerson(person);
      setState(() => _selectedPerson = saved);
    }
    nameCtrl.dispose();
    phoneCtrl.dispose();
  }

  InputDecoration _inputDeco({String hint = '', String? prefix, String? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
        prefixText: prefix,
        prefixStyle: const TextStyle(
            color: Color(0xFF6C63FF), fontSize: 22, fontWeight: FontWeight.bold),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Colors.white54, fontSize: 16),
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  const _TypeBtn(
      {required this.label,
      required this.icon,
      required this.isSelected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: color.withOpacity(0.5), width: 1)
                  : null,
            ),
            child: Center(
              child: Text(
                '$icon $label',
                style: TextStyle(
                  color: isSelected ? color : Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
}

class _PersonSelector extends StatelessWidget {
  final List<Person> persons;
  final Person? selected;
  final void Function(Person) onSelect;
  final VoidCallback onAddNew;

  const _PersonSelector(
      {required this.persons,
      required this.selected,
      required this.onSelect,
      required this.onAddNew});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E2E),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => ListView(
          padding: const EdgeInsets.all(20),
          shrinkWrap: true,
          children: [
            const Text('Select Person',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.add_rounded, color: Color(0xFF6C63FF)),
              title: const Text('Add New Person',
                  style: TextStyle(
                      color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                onAddNew();
              },
            ),
            const Divider(color: Colors.white12),
            ...persons.map(
              (p) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6C63FF).withOpacity(0.2),
                  child: Text(p.initials,
                      style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold)),
                ),
                title:
                    Text(p.name, style: const TextStyle(color: Colors.white)),
                subtitle: p.phone != null
                    ? Text(p.phone!,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12))
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelect(p);
                },
              ),
            ),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Row(
          children: [
            if (selected != null) ...[
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    const Color(0xFF6C63FF).withOpacity(0.2),
                child: Text(selected!.initials,
                    style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selected!.name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    if (selected!.phone != null)
                      Text(selected!.phone!,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ] else ...[
              const Icon(Icons.person_add_rounded,
                  color: Colors.white38, size: 22),
              const SizedBox(width: 12),
              Text('Tap to select or add person',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 14)),
            ],
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final DateTime date;
  final void Function(DateTime) onPick;
  final String label;
  const _DatePickerField(
      {required this.date, required this.onPick, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date,
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
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: Color(0xFF6C63FF), size: 20),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(date),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _InterestTypeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF6C63FF).withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF6C63FF).withOpacity(0.5)
                  : Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF6C63FF) : Colors.white54,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      );
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFF59E0B).withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0xFFF59E0B).withOpacity(0.5)
                  : Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFFF59E0B) : Colors.white38,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      );
}

class _LoanPreview extends StatelessWidget {
  final double principal;
  final double interestAmount;
  final bool isRecurring;
  final String interestPeriod;
  final double interestRate;
  final SettingsProvider settings;

  const _LoanPreview({
    required this.principal,
    required this.interestAmount,
    required this.isRecurring,
    required this.interestPeriod,
    required this.interestRate,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF6C63FF), size: 16),
              const SizedBox(width: 6),
              const Text('Loan Preview',
                  style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          _PreviewRow(
              label: 'Principal',
              value: settings.formatAmountFull(principal)),
          if (!isRecurring && interestAmount > 0) ...[
            _PreviewRow(
                label: 'Interest',
                value: settings.formatAmountFull(interestAmount),
                color: const Color(0xFFF59E0B)),
            const Divider(color: Colors.white12),
            _PreviewRow(
              label: 'Total Expected',
              value: settings.formatAmountFull(principal + interestAmount),
              color: Colors.white,
              bold: true,
            ),
          ],
          if (isRecurring)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+ $interestRate% $interestPeriod interest will accrue over time',
                style: const TextStyle(
                    color: Color(0xFFF59E0B), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _PreviewRow(
      {required this.label,
      required this.value,
      this.color = Colors.white70,
      this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );
}
