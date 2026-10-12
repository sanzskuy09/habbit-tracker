import '../models/habit.dart';

abstract interface class ReminderService {
  /// Null berarti seluruh jadwal berhasil disinkronkan. Tidak meminta izin
  /// saat startup; requestPermission hanya dari aksi pengguna.
  Future<String?> sync(List<Habit> habits, {bool requestPermission = false});
}

class NoopReminderService implements ReminderService {
  const NoopReminderService();

  @override
  Future<String?> sync(
    List<Habit> habits, {
    bool requestPermission = false,
  }) async => null;
}

class ReminderException implements Exception {
  const ReminderException(this.message);
  final String message;
}
