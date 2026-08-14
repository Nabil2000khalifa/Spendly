import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:csv/csv.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/loan_provider.dart';
import '../widgets/app_logo.dart';
import 'package:intl/intl.dart';
import 'accounts_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Header ──────────────────────────────────────
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // ── Currency Section ────────────────────────────
            _SectionTitle(title: 'Currency'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: settings.currency,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E1E2E),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6C63FF)),
                  items: SettingsProvider.supportedCurrencies.map((cur) {
                    return DropdownMenuItem<String>(
                      value: cur['code'],
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                cur['symbol']!,
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  cur['name']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  cur['code']!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final found = SettingsProvider.supportedCurrencies
                          .firstWhere((c) => c['code'] == val);
                      settings.setCurrency(found['code']!, found['symbol']!);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Accounts Section ──────────────────────────────
            _SectionTitle(title: 'Accounts & Banking'),
            const SizedBox(height: 12),
            _SettingsActionCard(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF6C63FF),
              title: 'Manage Accounts',
              subtitle: 'Bank accounts, cash, wallets, transfers, and balances',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountsScreen()),
              ),
            ),

            const SizedBox(height: 24),

            // ── Export Section ──────────────────────────────
            _SectionTitle(title: 'Export Data'),
            const SizedBox(height: 12),
            _SettingsActionCard(
              icon: Icons.table_chart_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Export as CSV',
              subtitle: 'Download all transactions in spreadsheet format',
              onTap: () => _exportCsv(context),
            ),
            const SizedBox(height: 10),
            _SettingsActionCard(
              icon: Icons.picture_as_pdf_rounded,
              iconColor: const Color(0xFFFF6B6B),
              title: 'Export as PDF',
              subtitle: 'Download a formatted PDF report',
              onTap: () => _exportPdf(context),
            ),
            const SizedBox(height: 10),
            _SettingsActionCard(
              icon: Icons.handshake_rounded,
              iconColor: const Color(0xFF6C63FF),
              title: 'Export Loans CSV',
              subtitle: 'Export all loan transactions in spreadsheet format',
              onTap: () => _exportLoansCsv(context),
            ),

            const SizedBox(height: 24),

            // ── Danger Zone ─────────────────────────────────
            _SectionTitle(title: 'Danger Zone'),
            const SizedBox(height: 12),
            _SettingsActionCard(
              icon: Icons.delete_forever_rounded,
              iconColor: const Color(0xFFEF4444),
              title: 'Delete All Data',
              subtitle: 'Permanently remove all transactions',
              isDanger: true,
              onTap: () => _confirmDelete(context),
            ),

            const SizedBox(height: 30),

            // ── App Info ────────────────────────────────────
            Center(
              child: Column(
                children: [
                  const AppLogo(size: 58, showLabel: false),
                  const SizedBox(height: 8),
                  const Text(
                    'Spendly',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final provider = context.read<ExpenseProvider>();
      final expenses = await provider.getAllExpensesForExport();

      final rows = [
        ['Date', 'Title', 'Amount', 'Type', 'Category', 'Currency', 'Note'],
        ...expenses.map((e) {
          final cat = provider.getCategoryById(e.categoryId);
          return [
            DateFormat('yyyy-MM-dd').format(e.date),
            e.title,
            e.amount.toStringAsFixed(2),
            e.type,
            cat?.name ?? 'Unknown',
            e.currency,
            e.note ?? '',
          ];
        }),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/expenses_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Expense Manager - CSV Export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    try {
      final provider = context.read<ExpenseProvider>();
      final settings = context.read<SettingsProvider>();
      final expenses = await provider.getAllExpensesForExport();

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text('Expense Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Generated: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}'),
            pw.Text('Currency: ${settings.currency}'),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ['Date', 'Title', 'Category', 'Type', 'Amount'],
              data: expenses.map((e) {
                final cat = provider.getCategoryById(e.categoryId);
                return [
                  DateFormat('MMM d, yyyy').format(e.date),
                  e.title,
                  cat?.name ?? 'Unknown',
                  e.type,
                  '${e.isExpense ? '-' : '+'}${settings.formatAmountFull(e.amount)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.indigo100),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(6),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Total Expenses: ${settings.formatAmountFull(expenses.where((e) => e.isExpense).fold(0.0, (s, e) => s + e.amount))}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Total Income: ${settings.formatAmountFull(expenses.where((e) => e.isIncome).fold(0.0, (s, e) => s + e.amount))}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/expenses_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Expense Manager - PDF Report',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportLoansCsv(BuildContext context) async {
    try {
      final loanProvider = context.read<LoanProvider>();
      final data = await loanProvider.getAllLoanDataForExport();

      final rows = [
        [
          'Person', 'Loan Type', 'Principal', 'Status', 'Start Date',
          'Due Date', 'Entry Type', 'Amount', 'Description',
          'Payment Method', 'Entry Date'
        ],
        ...data.map((row) => [
          row['person_name'],
          row['loan_type'],
          ((row['principal_paise'] as int) / 100).toStringAsFixed(2),
          row['status'],
          row['start_date'],
          row['due_date'] ?? '',
          row['entry_type'],
          ((row['amount_paise'] as int) / 100).toStringAsFixed(2),
          row['description'],
          row['payment_method'] ?? '',
          row['entry_date'],
        ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/loans_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Expense Manager - Loans CSV Export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: \$e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete All Data?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently delete ALL transactions. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete All',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await context.read<ExpenseProvider>().deleteAllExpenses();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data deleted')),
      );
    }
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDanger;

  const _SettingsActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDanger
                ? iconColor.withOpacity(0.2)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: isDanger ? iconColor : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
