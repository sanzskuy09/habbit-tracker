import '../models/habit.dart';
import '../models/habit_log.dart';

/// Kontrak CRUD agar widget tidak bergantung langsung pada Hive.
abstract interface class HabitService {
  Future<List<Habit>> getHabits();
  Future<void> createHabit(Habit habit);
  Future<void> updateHabit(Habit habit);
  Future<void> deleteHabit(String id);
  Future<List<HabitLog>> getLogs();
  Future<void> setCompleted(String habitId, DateTime date, bool completed);
  Future<void> close();
}
