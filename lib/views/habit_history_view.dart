import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/habit_controller.dart';
import '../services/habit_streak.dart';
import '../theme/app_theme.dart';

class HabitHistoryView extends StatefulWidget {
  const HabitHistoryView({super.key, required this.habitId});

  final String habitId;

  @override
  State<HabitHistoryView> createState() => _HabitHistoryViewState();
}

class _HabitHistoryViewState extends State<HabitHistoryView> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final today = context.read<HabitController>().today;
    _month = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HabitController>();
    final matches = controller.habits.where(
      (habit) => habit.id == widget.habitId,
    );
    if (matches.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Habit tidak ditemukan.')),
      );
    }
    final habit = matches.first;
    final firstMonth = DateTime(
      habit.createdAt.toLocal().year,
      habit.createdAt.toLocal().month,
    );
    final lastMonth = DateTime(controller.today.year, controller.today.month);
    final offset = _month.weekday - DateTime.monday;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = ((offset + days) / 7).ceil() * 7;
    final completed = controller.logs
        .where(
          (log) =>
              log.habitId == habit.id &&
              log.completedAt.year == _month.year &&
              log.completedAt.month == _month.month,
        )
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat habit')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  habit.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('${controller.streak(habit)} hari terjadwal beruntun'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Bulan sebelumnya',
                      onPressed: _month.isAfter(firstMonth)
                          ? () => setState(
                              () => _month = DateTime(
                                _month.year,
                                _month.month - 1,
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatMonthYear(_month),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Bulan berikutnya',
                      onPressed: _month.isBefore(lastMonth)
                          ? () => setState(
                              () => _month = DateTime(
                                _month.year,
                                _month.month + 1,
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']
                      .map(
                        (label) => Expanded(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: cells,
                  itemBuilder: (context, index) {
                    final number = index - offset + 1;
                    if (number < 1 || number > days) {
                      return const SizedBox.shrink();
                    }
                    final date = DateTime(_month.year, _month.month, number);
                    final done =
                        !date.isAfter(controller.today) &&
                        controller.isCompleted(habit.id, date);
                    final scheduled =
                        HabitStreak.isScheduled(habit, date) &&
                        !date.isAfter(controller.today);
                    final isToday = date == controller.today;
                    return Semantics(
                      label:
                          '${MaterialLocalizations.of(context).formatFullDate(date)}: ${done
                              ? 'selesai'
                              : scheduled
                              ? 'belum selesai'
                              : 'di luar jadwal'}',
                      child: Container(
                        key: Key('history-day-$number'),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: done
                              ? AppTheme.primary
                              : scheduled
                              ? Colors.white
                              : Colors.transparent,
                          border: isToday
                              ? Border.all(color: AppTheme.primary, width: 2)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$number',
                          style: TextStyle(
                            color: done
                                ? Colors.white
                                : scheduled
                                ? Colors.black87
                                : Colors.grey,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text('$completed hari selesai pada bulan ini.'),
                const SizedBox(height: 12),
                const Text(
                  'Hijau: selesai · Putih: jadwal belum selesai · Abu-abu: di luar jadwal atau tanggal mendatang.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pencatatan dilakukan untuk hari ini melalui Dashboard.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
