import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';

class AddAccountScreen extends StatefulWidget {
  final Account? account; // null = create, non-null = edit
  const AddAccountScreen({super.key, this.account});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();
  final _last4Ctrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController();

  String _type = Account.typeBank;
  String _icon = '🏦';
  int _color = 0xFF6C63FF;
  bool _isDefault = false;

  bool get _isEditing => widget.account != null;

  static const _availableIcons = [
    '🏦', '💵', '👛', '💳', '💰', '🏦', '📱', '📈', '🏦', '💎', '🛒', '⚡'
  ];

  static const _availableColors = [
    0xFF6C63FF, // Purple
    0xFF10B981, // Emerald Green
    0xFF3B82F6, // Blue
    0xFFF59E0B, // Amber
    0xFFEC4899, // Pink
    0xFF8B5CF6, // Violet
    0xFF06B6D4, // Cyan
    0xFFEF4444, // Red
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final a = widget.account!;
      _nameCtrl.text = a.name;
      _type = a.type;
      _institutionCtrl.text = a.institutionName ?? '';
      _last4Ctrl.text = a.accountNumberLast4 ?? '';
      _openingBalanceCtrl.text = a.openingBalance.toStringAsFixed(2);
      _icon = a.icon;
      _color = a.color;
      _isDefault = a.isDefault;
    } else {
      _openingBalanceCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _institutionCtrl.dispose();
    _last4Ctrl.dispose();
    _openingBalanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Edit Account' : 'Add Account'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Account Name ───────────────────────────────────
              const Text('Account Name',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. HDFC Bank, Cash, Savings',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: const Color(0xFF1E1E2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Please enter name' : null,
              ),

              const SizedBox(height: 20),

              // ── Account Type ───────────────────────────────────
              const Text('Account Type',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E2E),
                    style: const TextStyle(color: Colors.white),
                    items: Account.types.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(Account.typeLabel(t)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _type = val;
                          _icon = Account.defaultIcon(val);
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Institution & Last 4 Digits Row ───────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bank / Institution',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _institutionCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Optional',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.3)),
                            filled: true,
                            fillColor: const Color(0xFF1E1E2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Last 4 Digits',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _last4Ctrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'e.g. 4582',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.3)),
                            filled: true,
                            fillColor: const Color(0xFF1E1E2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Opening Balance ───────────────────────────────
              Text('Opening Balance (${settings.currency})',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _openingBalanceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: const Color(0xFF1E1E2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (double.tryParse(v) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ── Icon Selector ─────────────────────────────────
              const Text('Icon',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availableIcons.map((ic) {
                  final isSel = _icon == ic;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = ic),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFF6C63FF).withOpacity(0.3)
                            : const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel
                              ? const Color(0xFF6C63FF)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                          child: Text(ic, style: const TextStyle(fontSize: 22))),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── Color Picker ──────────────────────────────────
              const Text('Account Color',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availableColors.map((c) {
                  final isSel = _color == c;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── Default Account Switch ────────────────────────
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Default Account',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: const Text(
                    'Automatically selected when adding expenses or income',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                value: _isDefault,
                activeColor: const Color(0xFF6C63FF),
                onChanged: (val) => setState(() => _isDefault = val),
              ),

              const SizedBox(height: 32),

              // ── Submit Button ─────────────────────────────────
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _isEditing ? 'Update Account' : 'Save Account',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final inst = _institutionCtrl.text.trim();
    final last4 = _last4Ctrl.text.trim();
    final openingBal = double.tryParse(_openingBalanceCtrl.text.trim()) ?? 0.0;
    final settings = context.read<SettingsProvider>();
    final accountProvider = context.read<AccountProvider>();

    final now = DateTime.now();

    if (_isEditing) {
      final updated = widget.account!.copyWith(
        name: name,
        type: _type,
        institutionName: inst.isNotEmpty ? inst : null,
        accountNumberLast4: last4.isNotEmpty ? last4 : null,
        openingBalancePaise: (openingBal * 100).round(),
        currency: settings.currency,
        icon: _icon,
        color: _color,
        isDefault: _isDefault,
        updatedAt: now,
      );
      await accountProvider.updateAccount(updated);
    } else {
      final newAcc = Account(
        name: name,
        type: _type,
        institutionName: inst.isNotEmpty ? inst : null,
        accountNumberLast4: last4.isNotEmpty ? last4 : null,
        openingBalancePaise: (openingBal * 100).round(),
        currency: settings.currency,
        icon: _icon,
        color: _color,
        isDefault: _isDefault,
        createdAt: now,
        updatedAt: now,
      );
      await accountProvider.addAccount(newAcc);
    }

    if (mounted) Navigator.pop(context);
  }
}
