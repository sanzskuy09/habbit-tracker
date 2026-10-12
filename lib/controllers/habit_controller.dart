import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../services/habit_service.dart';
import '../services/habit_streak.dart';
import '../services/reminder_service.dart';
import '../utils/habit_date.dart';

class HabitController extends ChangeNotifier with WidgetsBindingObserver {
  HabitController({
    required HabitService service,
    ReminderService reminders = const NoopReminderService(),
    DateTime Function()? clock,
    bool monitorDate = true,
  }) : _service = service,
       _reminders = reminders,
       _clock = clock ?? DateTime.now,
       _monitorDate = monitorDate {
    _today = HabitDate.day(_clock());
    if (_monitorDate) {
      WidgetsBinding.instance.addObserver(this);
      _scheduleMidnight();
    }
  }

  final HabitService _service;
  final ReminderService _reminders;
  final DateTime Function() _clock;
  final bool _monitorDate;
  late DateTime _today;
  List<Habit> _habits = [];
  List<HabitLog> _logs = [];
  bool _disposed = false;
  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  Timer? _midnightTimer;
  Future<void>? _loadFuture;
  Future<void> _reminderQueue = Future.value();
  int _reminderOperations = 0;
  String? _reminderWarning;

  List<Habit> get habits => List.unmodifiable(_habits);
  List<HabitLog> get logs => List.unmodifiable(_logs);
  DateTime get today => _today;
  DateTime get now => _clock();
  bool get loading => _loading;
  bool get busy => _busy;
  String? get loadError => _loadError;
  String? get reminderWarning => _reminderWarning;
  bool get reminderBusy => _reminderOperations > 0;
  List<Habit> get todayHabits =>
      _habits.where((habit) => HabitStreak.isScheduled(habit, _today)).toList();
  int get completedToday =>
      todayHabits.where((habit) => isCompleted(habit.id, _today)).length;

  bool isCompleted(String id, DateTime day) => _logs.any(
    (log) =>
        log.habitId == id &&
        HabitDate.key(log.completedAt) == HabitDate.key(day),
  );

  int streak(Habit habit) => HabitStreak.current(habit, _logs, _today);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() {
    if (_busy || _disposed) return Future.value();
    return _loadFuture ??= _load().whenComplete(() => _loadFuture = null);
  }

  Future<void> _load() async {
    _loading = true;
    _loadError = null;
    _notify();
    try {
      final habits = await _service.getHabits();
      final logs = await _service.getLogs();
      if (_disposed) return;
      _habits = habits;
      _logs = logs;
      refreshDate();
      await _syncReminders();
    } catch (_) {
      _loadError = 'Kebiasaan belum bisa dimuat. Coba lagi.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> _mutate(
    Future<void> Function() write,
    void Function() commit, {
    bool syncReminders = false,
    bool requestPermission = false,
  }) async {
    if (_busy || _loading || _loadError != null || _disposed) {
      throw StateError('Tunggu hingga data siap.');
    }
    _busy = true;
    _notify();
    try {
      await write();
      if (!_disposed) {
        commit();
        _notify();
        if (syncReminders) {
          await _syncReminders(requestPermission: requestPermission);
        }
      }
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _sortHabits() => _habits.sort((a, b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate == 0 ? a.id.compareTo(b.id) : byDate;
  });

  Future<void> createHabit(Habit habit) => _mutate(
    () => _service.createHabit(habit),
    () {
      _habits = [..._habits, habit];
      _sortHabits();
    },
    syncReminders: true,
    requestPermission: habit.reminderTime != null,
  );

  Future<void> updateHabit(Habit habit) => _mutate(
    () => _service.updateHabit(habit),
    () {
      _habits = _habits
          .map((item) => item.id == habit.id ? habit : item)
          .toList();
      _sortHabits();
    },
    syncReminders: true,
    requestPermission: habit.reminderTime != null,
  );

  Future<void> deleteHabit(String id) =>
      _mutate(() => _service.deleteHabit(id), () {
        _habits.removeWhere((habit) => habit.id == id);
        _logs.removeWhere((log) => log.habitId == id);
      }, syncReminders: true);

  Future<void> retryReminders() {
    if (_loading || _busy || reminderBusy || _loadError != null || _disposed) {
      return Future.value();
    }
    return _syncReminders(requestPermission: true);
  }

  Future<void> _syncReminders({bool requestPermission = false}) {
    _reminderOperations++;
    // Serialisasi mencegah sync pada resume menimpa jadwal edit/hapus terbaru.
    // Daftar dibaca saat giliran berjalan, bukan ketika operasi masuk antrean.
    _reminderQueue = _reminderQueue.then((_) async {
      try {
        if (_disposed) return;
        _reminderWarning = await _reminders.sync(
          habits,
          requestPermission: requestPermission,
        );
      } on ReminderException catch (error) {
        _reminderWarning = error.message;
      } catch (_) {
        _reminderWarning =
            'Pengingat belum bisa dijadwalkan. Data habit tetap tersimpan. Coba lagi.';
      } finally {
        _reminderOperations--;
        _notify();
      }
    });
    _notify();
    return _reminderQueue;
  }

  Future<void> toggleToday(Habit habit) async {
    refreshDate();
    final date = _today;
    final completed = isCompleted(habit.id, date);
    if (!completed && !HabitStreak.isScheduled(habit, date)) {
      throw StateError('Habit tidak dijadwalkan hari ini.');
    }
    await _mutate(() => _service.setCompleted(habit.id, date, !completed), () {
      _logs.removeWhere(
        (log) =>
            log.habitId == habit.id &&
            HabitDate.key(log.completedAt) == HabitDate.key(date),
      );
      if (!completed) {
        _logs.add(
          HabitLog(
            id: '${habit.id}:${HabitDate.key(date)}',
            habitId: habit.id,
            completedAt: date,
          ),
        );
      }
    });
  }

  void refreshDate() {
    final date = HabitDate.day(_clock());
    if (date == _today) return;
    _today = date;
    _notify();
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = _clock().toLocal();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(next.difference(now), () {
      if (_disposed) return;
      refreshDate();
      _scheduleMidnight();
      if (!_loading && _loadError == null && !_disposed) {
        unawaited(_syncReminders());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshDate();
      _scheduleMidnight();
      if (!_loading && _loadError == null && !_disposed) {
        unawaited(_syncReminders());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _midnightTimer?.cancel();
    if (_monitorDate) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
