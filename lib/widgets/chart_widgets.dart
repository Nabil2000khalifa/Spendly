import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category.dart';

// ─── Pie Chart ──────────────────────────────────────────────────────────────

class CategoryPieChart extends StatefulWidget {
  final Map<int, double> data;
  final List<ExpenseCategory> categories;

  const CategoryPieChart({
    super.key,
    required this.data,
    required this.categories,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return _emptyChart();

    final total = widget.data.values.fold(0.0, (a, b) => a + b);
    final sections = <PieChartSectionData>[];

    int idx = 0;
    for (final entry in widget.data.entries) {
      final cat = widget.categories.firstWhere(
        (c) => c.id == entry.key,
        orElse: () => const ExpenseCategory(
            name: 'Other', icon: '📦', color: 0xFF6B7280),
      );
      final isTouched = idx == _touchedIndex;
      final pct = total > 0 ? (entry.value / total * 100) : 0.0;

      sections.add(PieChartSectionData(
        value: entry.value,
        title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
        color: Color(cat.color),
        radius: isTouched ? 60 : 50,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ));
      idx++;
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 45,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (response?.touchedSection == null) {
                      _touchedIndex = -1;
                    } else {
                      _touchedIndex =
                          response!.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Legend(data: widget.data, categories: widget.categories, total: total),
      ],
    );
  }

  Widget _emptyChart() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart_outline_rounded,
                size: 48, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text(
              'No data this month',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Map<int, double> data;
  final List<ExpenseCategory> categories;
  final double total;

  const _Legend(
      {required this.data, required this.categories, required this.total});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: data.entries.map((entry) {
        final cat = categories.firstWhere(
          (c) => c.id == entry.key,
          orElse: () => const ExpenseCategory(
              name: 'Other', icon: '📦', color: 0xFF6B7280),
        );
        final pct = total > 0 ? (entry.value / total * 100) : 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Color(cat.color),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${cat.icon} ${cat.name} (${pct.toStringAsFixed(1)}%)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─── Bar Chart ──────────────────────────────────────────────────────────────

class MonthlyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const MonthlyBarChart({super.key, required this.data});

  static const _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No data available',
            style:
                TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          ),
        ),
      );
    }

    double maxY = 0;
    for (final d in data) {
      final e = (d['expense'] as double);
      final i = (d['income'] as double);
      if (e > maxY) maxY = e;
      if (i > maxY) maxY = i;
    }
    maxY = maxY <= 0 ? 100 : maxY * 1.3;

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < data.length; i++) {
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (data[i]['expense'] as double),
            color: const Color(0xFFFF6B6B),
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: (data[i]['income'] as double),
            color: const Color(0xFF10B981),
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
        barsSpace: 4,
      ));
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barGroups: groups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withOpacity(0.06),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= data.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _monthNames[data[idx]['month'] as int],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                    reservedSize: 24,
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF2D2D44),
                  getTooltipItem: (group, groupIdx, rod, rodIdx) {
                    final label = rodIdx == 0 ? 'Expense' : 'Income';
                    return BarTooltipItem(
                      '$label\n${rod.toY.toStringAsFixed(0)}',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ChartLegendItem(
                color: const Color(0xFFFF6B6B), label: 'Expenses'),
            const SizedBox(width: 20),
            _ChartLegendItem(color: const Color(0xFF10B981), label: 'Income'),
          ],
        ),
      ],
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.6), fontSize: 12)),
      ],
    );
  }
}
