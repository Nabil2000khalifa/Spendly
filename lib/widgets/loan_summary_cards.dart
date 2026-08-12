import 'package:flutter/material.dart';
import '../models/loan.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';

class LoanSummaryCards extends StatelessWidget {
  final LoanSummary summary;
  const LoanSummaryCards({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final net = summary.netPosition;
    final netPositive = net >= 0;

    return Column(
      children: [
        // ── Main net position card ─────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: netPositive
                  ? [const Color(0xFF0F3460), const Color(0xFF16213E)]
                  : [const Color(0xFF3D0000), const Color(0xFF1A0000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: netPositive
                  ? const Color(0xFF6C63FF).withOpacity(0.3)
                  : const Color(0xFFEF4444).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (netPositive
                        ? const Color(0xFF6C63FF)
                        : const Color(0xFFEF4444))
                    .withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Net Position',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${netPositive ? '+' : ''}${settings.formatAmountFull(net)}',
                    style: TextStyle(
                      color: netPositive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFFF6B6B),
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (netPositive
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444))
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      netPositive ? 'You are owed' : 'You owe',
                      style: TextStyle(
                        color: netPositive
                            ? const Color(0xFF10B981)
                            : const Color(0xFFFF6B6B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _NetMiniCard(
                      label: 'To Receive',
                      value: settings.formatAmount(summary.totalToReceive),
                      icon: Icons.arrow_downward_rounded,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NetMiniCard(
                      label: 'To Pay',
                      value: settings.formatAmount(summary.totalToPay),
                      icon: Icons.arrow_upward_rounded,
                      color: const Color(0xFFFF6B6B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Stats row ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatChip(
                label: 'Active',
                value: '${summary.activeCount}',
                color: const Color(0xFF6C63FF),
                icon: Icons.circle_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                label: 'Overdue',
                value: '${summary.overdueCount}',
                color: const Color(0xFFEF4444),
                icon: Icons.warning_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                label: 'Interest',
                value: settings.formatAmount(
                    summary.totalInterestEarned + summary.totalInterestOwed),
                color: const Color(0xFFF59E0B),
                icon: Icons.percent_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NetMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _NetMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
