import 'package:timezone/timezone.dart' as tz;

import '../models/habit.dart';
import 'reminder_service.dart';

class HabitReminder {
  const HabitReminder({
    required this.id,
    required this.habit,
    required this.at,
    required this.weekday,
  });

  final int id;
  final Habit habit;
  final tz.TZDateTime at;
  // Null = ulang setiap hari; 1..7 = ulang pada hari tersebut setiap minggu.
  final int? weekday;
}

class ReminderPlan {
  static const maxRequests = 64;

  static List<HabitReminder> build(List<Habit> habits, tz.TZDateTime now) {
    final enabled = habits.where((habit) => habit.reminderTime != null).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final result = <HabitReminder>[];
    for (final habit in enabled) {
      final time = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(habit.reminderTime!);
      final hour = time == null ? -1 : int.parse(time[1]!);
      final minute = time == null ? -1 : int.parse(time[2]!);
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        throw const ReminderException(
          'Jam pengingat tidak valid. Edit jam habit lalu coba lagi.',
        );
      }
      final List<int?> weekdays = switch (habit.frequency) {
        HabitFrequency.daily => [null],
        HabitFrequency.weekdays => [1, 2, 3, 4, 5],
        HabitFrequency.weekends => [6, 7],
      };
      for (final weekday in weekdays) {
        var next = tz.TZDateTime(
          now.location,
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );
        // Konstruktor kalender menjaga jam lokal ketika melewati DST.
        while (!next.isAfter(now) ||
            (weekday != null && next.weekday != weekday)) {
          next = tz.TZDateTime(
            now.location,
            next.year,
            next.month,
            next.day + 1,
            hour,
            minute,
          );
        }
        result.add(
          HabitReminder(
            id: result.length + 1,
            habit: habit,
            at: next,
            weekday: weekday,
          ),
        );
      }
    }
    if (result.length > maxRequests) {
      throw const ReminderException(
        'Pengingat belum dijadwalkan: batas 64 jadwal terlampaui. Kurangi pengingat atau gunakan frekuensi setiap hari, lalu coba lagi.',
      );
    }
    return result;
  }
}
