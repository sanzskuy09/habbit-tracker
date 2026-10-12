import '../models/habit.dart';
import '../models/habit_log.dart';
import '../utils/habit_date.dart';
import 'habit_streak.dart';

class DailyProgress {
  const DailyProgress({
    required this.date,
    required this.scheduled,
    required this.completed,
  });
  final DateTime date;
  final int scheduled;
  final int completed;
  double get percentage => scheduled == 0 ? 0 : completed / scheduled * 100;
}

class HabitStatistics {
  const HabitStatistics._(this.days);
  final List<DailyProgress> days;
  int get scheduled => days.fold(0, (total, day) => total + day.scheduled);
  int get completed => days.fold(0, (total, day) => total + day.completed);
  double get percentage => scheduled == 0 ? 0 : completed / scheduled * 100;

  static HabitStatistics calculate({
    required List<Habit> habits,
    required List<HabitLog> logs,
    required DateTime today,
    required int dayCount,
  }) {
    if (dayCount < 1) throw ArgumentError.value(dayCount, 'dayCount');
    final end = HabitDate.day(today);
    final completedDates = <String, Set<String>>{};
    for (final log in logs) {
      (completedDates[log.habitId] ??= {}).add(HabitDate.key(log.completedAt));
    }
    final result = <DailyProgress>[];
    for (var offset = dayCount - 1; offset >= 0; offset--) {
      final date = DateTime(end.year, end.month, end.day - offset);
      final eligible = habits
          .where((habit) => HabitStreak.isScheduled(habit, date))
          .toList();
      final key = HabitDate.key(date);
      result.add(
        DailyProgress(
          date: date,
          scheduled: eligible.length,
          completed: eligible
              .where(
                (habit) => completedDates[habit.id]?.contains(key) ?? false,
              )
              .length,
        ),
      );
    }
    return HabitStatistics._(List.unmodifiable(result));
  }
}
