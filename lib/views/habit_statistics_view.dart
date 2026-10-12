import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/habit_controller.dart';
import '../services/habit_statistics.dart';
import '../theme/app_theme.dart';

class HabitStatisticsView extends StatefulWidget {
  const HabitStatisticsView({super.key});

  @override
  State<HabitStatisticsView> createState() => _HabitStatisticsViewState();
}

class _HabitStatisticsViewState extends State<HabitStatisticsView> {
  int _dayCount = 7;

  Widget _summary(
    BuildContext context,
    String value,
    String label, {
    Key? key,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            key: key,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(label),
        ],
      ),
    ),
  );

  Widget _chart(BuildContext context, HabitStatistics stats) {
    final days = stats.days;
    return Semantics(
      label:
          'Grafik persentase penyelesaian harian. Rincian tersedia di bawah grafik.',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 240,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: 100,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Color(0xFFE3E7E3), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: 50,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        '${value.toInt()}%',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 ||
                          index >= days.length ||
                          (days.length > 7 &&
                              index != 0 &&
                              index != days.length - 1 &&
                              (index % 7 != 0 || index > days.length - 5))) {
                        return const SizedBox.shrink();
                      }
                      final date = days[index].date;
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '${date.day}/${date.month}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final day = days[group.x];
                    return BarTooltipItem(
                      '${day.date.day}/${day.date.month}\n${day.completed}/${day.scheduled} selesai',
                      const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var index = 0; index < days.length; index++)
                  BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: days[index].percentage,
                        width: days.length == 7 ? 18 : 5,
                        color: AppTheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HabitController>();
    final stats = HabitStatistics.calculate(
      habits: controller.habits,
      logs: controller.logs,
      today: controller.today,
      dayCount: _dayCount,
    );
    final localizations = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Konsistensi rutinitasmu',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Persentase dihitung dari jadwal habit yang masih tersimpan, termasuk hari ini.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final count in [7, 30])
                      ChoiceChip(
                        label: Text('$count hari terakhir'),
                        selected: _dayCount == count,
                        onSelected: (_) => setState(() => _dayCount = count),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${localizations.formatShortDate(stats.days.first.date)} – ${localizations.formatShortDate(stats.days.last.date)}',
                ),
                const SizedBox(height: 12),
                _summary(
                  context,
                  stats.scheduled == 0
                      ? '—'
                      : '${stats.percentage.toStringAsFixed(0)}%',
                  'Penyelesaian periode ini',
                  key: const Key('statistics-percentage'),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _summary(
                        context,
                        '${stats.completed}',
                        'Selesai',
                        key: const Key('statistics-completed'),
                      ),
                    ),
                    Expanded(
                      child: _summary(
                        context,
                        '${stats.scheduled}',
                        'Jadwal',
                        key: const Key('statistics-scheduled'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Progres per hari',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (stats.scheduled == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Belum ada jadwal pada periode ini. Tambahkan habit untuk mulai melihat progres.',
                    ),
                  )
                else
                  _chart(context, stats),
                const SizedBox(height: 12),
                const Text(
                  'Hari di luar jadwal dan hari sebelum habit dibuat tidak dihitung. Mengubah frekuensi menghitung ulang statistik dengan jadwal terbaru.',
                ),
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Rincian harian'),
                  children: [
                    for (final day in stats.days.reversed)
                      ListTile(
                        title: Text(localizations.formatShortDate(day.date)),
                        subtitle: Text(
                          day.scheduled == 0
                              ? 'Tidak ada jadwal'
                              : '${day.completed} dari ${day.scheduled} selesai · ${day.percentage.toStringAsFixed(0)}%',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
