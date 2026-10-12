import 'package:hive_flutter/hive_flutter.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../utils/habit_date.dart';
import 'habit_service.dart';
import 'habit_streak.dart';

class HiveHabitService implements HabitService {
  HiveHabitService._(this._box);

  static const boxName = 'habits_v1';
  final Box<Map> _box;

  /// directory hanya diperlukan tes; aplikasi memakai direktori dokumen lokal.
  static Future<HiveHabitService> open({String? directory}) async {
    if (directory == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(directory);
    }
    final box = await Hive.openBox<Map>(boxName);
    return HiveHabitService._(box);
  }

  @override
  Future<List<Habit>> getHabits() async {
    final habits = _box.values
        .where((map) => map['recordType'] != 'habit_log')
        .map((map) => Habit.fromMap(Map<String, dynamic>.from(map)))
        .toList();
    // Habit terbaru tampil dahulu. ID membuat urutan stabil jika waktu sama.
    habits.sort((a, b) {
      final byDate = b.createdAt.compareTo(a.createdAt);
      return byDate == 0 ? a.id.compareTo(b.id) : byDate;
    });
    return habits;
  }

  @override
  Future<void> createHabit(Habit habit) async {
    _validate(habit);
    if (_box.containsKey(habit.id)) {
      throw StateError('Habit dengan ID ini sudah ada.');
    }
    // Tunggu penulisan selesai sebelum UI menganggap penyimpanan berhasil.
    await _box.put(habit.id, habit.toMap());
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    _validate(habit);
    final previous = _box.get(habit.id);
    if (previous == null) throw StateError('Habit tidak ditemukan.');
    if (previous['createdAt'] != habit.createdAt.toIso8601String()) {
      throw ArgumentError('Tanggal pembuatan habit tidak boleh berubah.');
    }
    await _box.put(habit.id, habit.toMap());
  }

  @override
  Future<void> deleteHabit(String id) async {
    if (!_box.containsKey(id)) throw StateError('Habit tidak ditemukan.');
    final logKeys = _box
        .toMap()
        .entries
        .where(
          (entry) =>
              entry.value['recordType'] == 'habit_log' &&
              entry.value['habitId'] == id,
        )
        .map((entry) => entry.key);
    // Satu batch dalam box yang sama menghapus habit beserta riwayatnya.
    await _box.deleteAll([id, ...logKeys]);
  }

  @override
  Future<List<HabitLog>> getLogs() async => _box.values
      .where((map) => map['recordType'] == 'habit_log')
      .map((map) => HabitLog.fromMap(Map<String, dynamic>.from(map)))
      .where((log) => _box.containsKey(log.habitId))
      .toList();

  @override
  Future<void> setCompleted(
    String habitId,
    DateTime date,
    bool completed,
  ) async {
    final map = _box.get(habitId);
    if (map == null || map['recordType'] == 'habit_log') {
      throw StateError('Habit tidak ditemukan.');
    }
    final habit = Habit.fromMap(Map<String, dynamic>.from(map));
    final day = HabitDate.day(date);
    // Pembatalan tetap diperbolehkan untuk log lama sesudah frekuensi diedit.
    if (completed && !HabitStreak.isScheduled(habit, day)) {
      throw ArgumentError('Habit tidak dijadwalkan pada tanggal ini.');
    }
    final id = '$habitId:${HabitDate.key(day)}';
    final key = 'log:$id';
    if (completed) {
      final log = HabitLog(id: id, habitId: habitId, completedAt: day);
      await _box.put(key, log.toMap());
    } else {
      await _box.delete(key);
    }
  }

  static void _validate(Habit habit) {
    if (habit.id.trim().isEmpty || habit.title.trim().isEmpty) {
      throw ArgumentError('ID dan nama habit wajib diisi.');
    }
  }

  @override
  Future<void> close() => _box.close();
}
