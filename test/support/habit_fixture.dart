import 'package:habit_tracker/models/habit.dart';

Habit habitFixture({
  String id = 'read',
  String title = 'Baca buku',
  String description = 'Baca selama 15 menit',
  int colorHex = 0xFF24786B,
  String iconKey = 'book',
  HabitFrequency frequency = HabitFrequency.weekdays,
  String? reminderTime = '20:15',
  DateTime? createdAt,
}) => Habit(
  id: id,
  title: title,
  description: description,
  colorHex: colorHex,
  iconKey: iconKey,
  frequency: frequency,
  reminderTime: reminderTime,
  createdAt: createdAt ?? DateTime(2026, 10, 9, 7, 30),
);
