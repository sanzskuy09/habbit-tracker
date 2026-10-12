import '../models/habit.dart';
import '../models/habit_log.dart';
import '../utils/habit_date.dart';

/// Logika murni Dart agar aturan tanggal bisa diuji tanpa widget/database.
abstract final class HabitStreak {
  static bool isScheduled(Habit habit, DateTime value) {
    final date = HabitDate.day(value);
    if (date.isBefore(HabitDate.day(habit.createdAt))) return false;
    return switch (habit.frequency) {
      HabitFrequency.daily => true,
      HabitFrequency.weekdays => date.weekday <= DateTime.friday,
      HabitFrequency.weekends => date.weekday >= DateTime.saturday,
    };
  }

  static DateTime _previousScheduled(Habit habit, DateTime date) {
    var previous = HabitDate.previous(date);
    final created = HabitDate.day(habit.createdAt);
    while (!previous.isBefore(created) && !isScheduled(habit, previous)) {
      previous = HabitDate.previous(previous);
    }
    return previous;
  }

  static int current(Habit habit, Iterable<HabitLog> logs, DateTime now) {
    final today = HabitDate.day(now);
    final completed = logs
        .where(
          (log) =>
              log.habitId == habit.id &&
              !HabitDate.day(log.completedAt).isAfter(today) &&
              isScheduled(habit, log.completedAt),
        )
        .map((log) => HabitDate.key(log.completedAt))
        .toSet();
    // Hari ini masih terbuka. Jika belum selesai, mulai dari jadwal sebelumnya.
    var date =
        isScheduled(habit, today) && completed.contains(HabitDate.key(today))
        ? today
        : _previousScheduled(habit, today);
    var count = 0;
    while (!date.isBefore(HabitDate.day(habit.createdAt)) &&
        completed.contains(HabitDate.key(date))) {
      count++;
      date = _previousScheduled(habit, date);
    }
    return count;
  }
}
