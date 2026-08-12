import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../providers/settings_provider.dart';

class LoanCard extends StatelessWidget {
  final LoanWithDetails loanDetails;
  final VoidCallback? onTap;

  const LoanCard({super.key, required this.loanDetails, this.onTap});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final ld = loanDetails;
    final status = ld.computedStatus;
    final statusColor = ld.statusColor;
    final isLent = ld.loan.isLent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: status == LoanStatus.overdue
                ? const Color(0xFFEF4444).withOpacity(0.3)
                : Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // ── Person avatar ────────────────────────────
                _PersonAvatar(name: ld.person.name, isLent: isLent),
                const SizedBox(width: 12),

                // ── Info ─────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ld.person.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _StatusBadge(
                              label: ld.statusLabel, color: statusColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isLent
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFF6B6B))
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isLent ? '↑ I Lent' : '↓ I Borrowed',
                              style: TextStyle(
                                color: isLent
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFFF6B6B),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (ld.loan.dueDate != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 10,
                              color: Colors.white.withOpacity(0.4),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM d').format(ld.loan.dueDate!),
                              style: TextStyle(
                                color: status == LoanStatus.overdue
                                    ? const Color(0xFFEF4444)
                                    : Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Amounts row ───────────────────────────────────
            Row(
              children: [
                _AmountInfo(
                  label: 'Principal',
                  value: settings.formatAmount(ld.principalAmount),
                  color: Colors.white.withOpacity(0.5),
                ),
                _vDivider(),
                _AmountInfo(
                  label: 'Interest',
                  value: settings.formatAmount(ld.totalInterestCharged),
                  color: const Color(0xFFF59E0B),
                ),
                _vDivider(),
                _AmountInfo(
                  label: 'Outstanding',
                  value: settings.formatAmount(ld.balance),
                  color: status == LoanStatus.paid
                      ? const Color(0xFF10B981)
                      : isLent
                          ? const Color(0xFF10B981)
                          : const Color(0xFFFF6B6B),
                  bold: true,
                ),
              ],
            ),

            if (ld.totalPaid > 0) ...[
              const SizedBox(height: 10),
              // ── Progress bar ─────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ld.progressPct,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paid: ${settings.formatAmount(ld.totalPaid)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${(ld.progressPct * 100).toStringAsFixed(0)}% complete',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withOpacity(0.08),
      );
}

// ─── Person Avatar ────────────────────────────────────────────────────────────

class _PersonAvatar extends StatelessWidget {
  final String name;
  final bool isLent;
  const _PersonAvatar({required this.name, required this.isLent});

  @override
  Widget build(BuildContext context) {
    final color = isLent ? const Color(0xFF10B981) : const Color(0xFFFF6B6B);
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─── Status Badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Amount Info Cell ──────────────────────────────────────────────────────────

class _AmountInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _AmountInfo({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
