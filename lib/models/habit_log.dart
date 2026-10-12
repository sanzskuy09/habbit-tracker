import '../utils/habit_date.dart';

/// Satu catatan per habit per tanggal lokal, tanpa komponen jam.
class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.completedAt,
  });

  final String id;
  final String habitId;
  final DateTime completedAt;

  Map<String, dynamic> toMap() => {
    'recordType': 'habit_log',
    'id': id,
    'habitId': habitId,
    'completedAt': HabitDate.key(completedAt),
  };

  factory HabitLog.fromMap(Map<String, dynamic> map) => HabitLog(
    id: map['id'] as String,
    habitId: map['habitId'] as String,
    completedAt: DateTime.parse(map['completedAt'] as String),
  );
}
