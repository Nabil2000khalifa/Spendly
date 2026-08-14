import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/account_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expense;
  final String initialType;

  const AddExpenseScreen({
    super.key,
    this.expense,
    this.initialType = 'expense',
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late String _type;
  DateTime _selectedDate = DateTime.now();
  ExpenseCategory? _selectedCategory;
  Account? _selectedAccount;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _type = widget.expense?.type ?? widget.initialType;

    if (_isEditing) {
      final e = widget.expense!;
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toString();
      _noteCtrl.text = e.note ?? '';
      _selectedDate = e.date;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accountProvider = context.watch<AccountProvider>();

    if (_isEditing && _selectedCategory == null) {
      final cats = context.read<ExpenseProvider>().categories;
      try {
        _selectedCategory =
            cats.firstWhere((c) => c.id == widget.expense!.categoryId);
      } catch (_) {}
    } else if (_selectedCategory == null) {
      final cats = context.read<ExpenseProvider>().categories;
      if (cats.isNotEmpty) _selectedCategory = cats.first;
    }

    if (_selectedAccount == null) {
      if (_isEditing && widget.expense!.accountId != null) {
        _selectedAccount =
            accountProvider.getAccountById(widget.expense!.accountId);
      }
      _selectedAccount ??= accountProvider.defaultAccount ??
          (accountProvider.activeAccounts.isNotEmpty
              ? accountProvider.activeAccounts.first
              : null);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C63FF),
            surface: Color(0xFF1E1E2E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final provider = context.read<ExpenseProvider>();
    final settings = context.read<SettingsProvider>();
    final accountProvider = context.read<AccountProvider>();

    final expense = Expense(
      id: widget.expense?.id,
      title: _titleCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.trim()),
      categoryId: _selectedCategory!.id!,
      accountId: _selectedAccount?.id ?? accountProvider.defaultAccount?.id,
      date: _selectedDate,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      type: _type,
      currency: settings.currency,
    );

    if (_isEditing) {
      await provider.updateExpense(expense);
    } else {
      await provider.addExpense(expense);
    }

    await accountProvider.loadAccounts();

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ExpenseProvider>().categories;
    final isExpenseType = _type == 'expense';

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Transaction' : 'New Transaction',
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFFF6B6B)),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E2E),
                    title: const Text('Delete?',
                        style: TextStyle(color: Colors.white)),
                    content: const Text('Remove this transaction?',
                        style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style:
                                  TextStyle(color: Color(0xFFFF6B6B)))),
                    ],
                  ),
                );
                if (ok == true && mounted) {
                  await context
                      .read<ExpenseProvider>()
                      .deleteExpense(widget.expense!.id!);
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Type Toggle ─────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _TypeBtn(
                    label: 'Expense',
                    icon: Icons.remove_rounded,
                    isSelected: isExpenseType,
                    color: const Color(0xFFFF6B6B),
                    onTap: () => setState(() => _type = 'expense'),
                  ),
                  _TypeBtn(
                    label: 'Income',
                    icon: Icons.add_rounded,
                    isSelected: !isExpenseType,
                    color: const Color(0xFF10B981),
                    onTap: () => setState(() => _type = 'income'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Amount ──────────────────────────────────────
            _buildLabel('Amount'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              decoration: _inputDeco(
                hint: '0.00',
                prefix: context.watch<SettingsProvider>().currencySymbol,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                if (double.tryParse(v) == null) return 'Invalid number';
                if (double.parse(v) <= 0) return 'Amount must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Title ───────────────────────────────────────
            _buildLabel('Title'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration:
                  _inputDeco(hint: 'e.g. Lunch, Netflix, Salary...'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter a title' : null,
            ),
            const SizedBox(height: 20),

            // ── Category ────────────────────────────────────
            _buildLabel('Category'),
            const SizedBox(height: 8),
            _CategoryPicker(
              categories: categories,
              selected: _selectedCategory,
              onSelect: (cat) => setState(() => _selectedCategory = cat),
            ),
            const SizedBox(height: 20),

            // ── Account ─────────────────────────────────────
            _buildLabel('Account'),
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

            // ── Date ────────────────────────────────────────
            _buildLabel('Date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Color(0xFF6C63FF), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Note ────────────────────────────────────────
            _buildLabel('Note (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _inputDeco(hint: 'Add a note...'),
            ),

            const SizedBox(height: 30),

            // ── Save Button ─────────────────────────────────
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpenseType
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isEditing ? 'Update Transaction' : 'Add ${_type == 'expense' ? 'Expense' : 'Income'}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );

  InputDecoration _inputDeco({String hint = '', String? prefix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
      prefixText: prefix,
      prefixStyle: const TextStyle(
          color: Color(0xFF6C63FF),
          fontSize: 22,
          fontWeight: FontWeight.bold),
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
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ─── Type Toggle Button ──────────────────────────────────────────────────────

class _TypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeBtn({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isSelected ? color : Colors.white.withOpacity(0.4),
                  size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Category Picker ─────────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  final List<ExpenseCategory> categories;
  final ExpenseCategory? selected;
  final void Function(ExpenseCategory) onSelect;

  const _CategoryPicker({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final isSelected = selected?.id == cat.id;
        final color = Color(cat.color);
        return GestureDetector(
          onTap: () => onSelect(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.2)
                  : const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? color.withOpacity(0.6)
                    : Colors.white.withOpacity(0.08),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  cat.name,
                  style: TextStyle(
                    color: isSelected ? color : Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
