/// Hari kalender lokal: tidak memakai selisih jam yang rentan perubahan DST.
abstract final class HabitDate {
  static DateTime day(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime previous(DateTime value) {
    final date = day(value);
    return DateTime(date.year, date.month, date.day - 1);
  }

  static String key(DateTime value) {
    final date = day(value);
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
