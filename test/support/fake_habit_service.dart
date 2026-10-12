import 'dart:async';

import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/models/habit_log.dart';
import 'package:habit_tracker/services/habit_service.dart';
import 'package:habit_tracker/utils/habit_date.dart';

/// Widget tests mengontrol kegagalan/penundaan I/O tanpa platform channel.
/// Persistensi sesungguhnya diuji dengan Hive di hive_habit_service_test.dart.
class FakeHabitService implements HabitService {
  final habits = <String, Habit>{};
  final logs = <String, HabitLog>{};
  bool failRead = false;
  bool failSave = false;
  bool failDelete = false;
  bool failCompletion = false;
  Completer<void>? completionGate;
  Completer<void>? saveGate;
  int createCalls = 0;

  @override
  Future<List<Habit>> getHabits() async {
    if (failRead) throw StateError('Read failed');
    return habits.values.toList();
  }

  @override
  Future<void> createHabit(Habit habit) async {
    createCalls++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Write failed');
    habits[habit.id] = habit;
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    if (failSave) throw StateError('Write failed');
    habits[habit.id] = habit;
  }

  @override
  Future<void> deleteHabit(String id) async {
    if (failDelete) throw StateError('Delete failed');
    habits.remove(id);
    logs.removeWhere((key, log) => log.habitId == id);
  }

  @override
  Future<List<HabitLog>> getLogs() async {
    if (failRead) throw StateError('Read failed');
    return logs.values.toList();
  }

  @override
  Future<void> setCompleted(
    String habitId,
    DateTime date,
    bool completed,
  ) async {
    if (completionGate != null) await completionGate!.future;
    if (failCompletion) throw StateError('Write failed');
    final key = '$habitId:${HabitDate.key(date)}';
    if (completed) {
      logs[key] = HabitLog(
        id: key,
        habitId: habitId,
        completedAt: HabitDate.day(date),
      );
    } else {
      logs.remove(key);
    }
  }

  @override
  Future<void> close() async {}
}
