import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';
import 'add_account_screen.dart';
import 'account_detail_screen.dart';
import 'add_transfer_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final settings = context.watch<SettingsProvider>();
    final active = accountProvider.activeAccounts;
    final inactive = accountProvider.inactiveAccounts;
    final totalBalance = accountProvider.totalBalance;

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Accounts & Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_alt_rounded, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddTransferScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Total Combined Balance Card ────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Balance',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${active.length} Active Accounts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (accountProvider.isMultiCurrency) ...[
                    ...accountProvider.balancesByCurrency.entries.map((e) {
                      final sym = SettingsProvider.symbolForCurrency(e.key);
                      return Text(
                        '$sym${e.value.toStringAsFixed(2)} ${e.key}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      );
                    }),
                  ] else ...[
                    Text(
                      // Use the first active account's currency symbol
                      '${active.isNotEmpty ? active.first.currencySymbol : settings.currencySymbol}${totalBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Active Accounts List Header ────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Accounts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddAccountScreen()),
                  ),
                  icon: const Icon(Icons.add, size: 18, color: Color(0xFF6C63FF)),
                  label: const Text('Add Account',
                      style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Active Accounts List ───────────────────────────
            active.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('No active accounts',
                          style: TextStyle(color: Colors.white38)),
                    ),
                  )
                : Column(
                    children: active.map((acc) {
                      final bal = accountProvider.getBalance(acc.id!);
                      return _AccountCard(
                        account: acc,
                        balance: bal,
                        settings: settings,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AccountDetailScreen(accountId: acc.id!),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

            // ── Inactive Accounts Section ───────────────────────
            if (inactive.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Deactivated Accounts (${inactive.length})',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: inactive.map((acc) {
                  final bal = accountProvider.getBalance(acc.id!);
                  return _AccountCard(
                    account: acc,
                    balance: bal,
                    settings: settings,
                    isInactive: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AccountDetailScreen(accountId: acc.id!),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddAccountScreen()),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Account',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final double balance;
  final SettingsProvider settings;
  final bool isInactive;
  final VoidCallback onTap;

  const _AccountCard({
    required this.account,
    required this.balance,
    required this.settings,
    this.isInactive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(account.color);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isInactive
              ? const Color(0xFF1E1E2E).withOpacity(0.5)
              : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isInactive
                ? Colors.white10
                : account.isDefault
                    ? const Color(0xFF6C63FF).withOpacity(0.4)
                    : Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child:
                    Text(account.icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          account.name,
                          style: TextStyle(
                            color: isInactive ? Colors.white54 : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (account.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Default',
                              style: TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${account.typeDisplayName}${account.accountNumberDisplay.isNotEmpty ? ' · ${account.accountNumberDisplay}' : ''}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              // Use account's own currency symbol — not global settings
              '${account.currencySymbol}${balance >= 0 ? '' : '-'}${balance.abs() >= 1000 ? '${(balance.abs() / 1000).toStringAsFixed(1)}K' : balance.abs().toStringAsFixed(2)}',
              style: TextStyle(
                color: isInactive
                    ? Colors.white38
                    : balance >= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFFF6B6B),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
