import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/transfer.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';

class AddTransferScreen extends StatefulWidget {
  final Account? initialFromAccount;
  const AddTransferScreen({super.key, this.initialFromAccount});

  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Account? _fromAccount;
  Account? _toAccount;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fromAccount = widget.initialFromAccount;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<AccountProvider>();
    final active = provider.activeAccounts;

    if (_fromAccount == null && active.isNotEmpty) {
      _fromAccount = active.first;
    }

    if (_toAccount == null && active.length > 1) {
      _toAccount = active.firstWhere(
        (a) => a.id != _fromAccount?.id,
        orElse: () => active.last,
      );
    }
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
    final provider = context.watch<AccountProvider>();
    final active = provider.activeAccounts;

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Transfer Money'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── From Account ────────────────────────────────────
              const Text('From Account',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Account>(
                    value: _fromAccount,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E2E),
                    style: const TextStyle(color: Colors.white),
                    items: active.map((acc) {
                      final bal = provider.getBalance(acc.id!);
                      return DropdownMenuItem(
                        value: acc,
                        child: Row(
                          children: [
                            Text(acc.icon, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(acc.name)),
                            Text(
                              settings.formatAmount(bal),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _fromAccount = val;
                          if (_toAccount?.id == val.id && active.length > 1) {
                            _toAccount = active.firstWhere((a) => a.id != val.id);
                          }
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Transfer Arrow Icon ─────────────────────────────
              Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.south_rounded,
                      color: Color(0xFF6C63FF), size: 20),
                ),
              ),

              const SizedBox(height: 16),

              // ── To Account ──────────────────────────────────────
              const Text('To Account',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Account>(
                    value: _toAccount,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E2E),
                    style: const TextStyle(color: Colors.white),
                    items: active.map((acc) {
                      final bal = provider.getBalance(acc.id!);
                      return DropdownMenuItem(
                        value: acc,
                        child: Row(
                          children: [
                            Text(acc.icon, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(acc.name)),
                            Text(
                              settings.formatAmount(bal),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _toAccount = val;
                          if (_fromAccount?.id == val.id && active.length > 1) {
                            _fromAccount =
                                active.firstWhere((a) => a.id != val.id);
                          }
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Amount ──────────────────────────────────────────
              Text('Amount (${settings.currency})',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
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
                  if (v == null || v.trim().isEmpty) return 'Enter amount';
                  final val = double.tryParse(v);
                  if (val == null || val <= 0) return 'Enter valid positive amount';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ── Date Picker ─────────────────────────────────────
              const Text('Date',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: Color(0xFF6C63FF), size: 18),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy').format(_date),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Description / Note ──────────────────────────────
              const Text('Note (Optional)',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Monthly savings transfer',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: const Color(0xFF1E1E2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Submit Button ─────────────────────────────────
              ElevatedButton(
                onPressed: _saveTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Confirm Transfer',
                  style: TextStyle(
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C63FF),
              surface: Color(0xFF1E1E2E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _saveTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromAccount == null || _toAccount == null) return;

    if (_fromAccount!.id == _toAccount!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select different accounts')),
      );
      return;
    }

    if (_fromAccount!.currency != _toAccount!.currency) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot transfer between different currencies (${_fromAccount!.currency} to ${_toAccount!.currency})')),
      );
      return;
    }

    final amt = double.parse(_amountCtrl.text.trim());
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer amount must be greater than zero')),
      );
      return;
    }

    final note = _noteCtrl.text.trim();

    final transfer = AccountTransfer(
      fromAccountId: _fromAccount!.id!,
      toAccountId: _toAccount!.id!,
      amountPaise: (amt * 100).round(),
      date: _date,
      note: note.isNotEmpty ? note : null,
      createdAt: DateTime.now(),
    );

    await context.read<AccountProvider>().addTransfer(transfer);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Transferred ${context.read<SettingsProvider>().formatAmount(amt)} from ${_fromAccount!.name} to ${_toAccount!.name}'),
        ),
      );
      Navigator.pop(context);
    }
  }
}
