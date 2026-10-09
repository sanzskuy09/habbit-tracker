enum HabitFrequency {
  daily('Setiap hari'),
  weekdays('Senin–Jumat'),
  weekends('Sabtu–Minggu');

  const HabitFrequency(this.label);

  final String label;
}

/// Model data murni Dart; tidak bergantung pada widget atau database.
class Habit {
  const Habit({
    required this.id,
    required this.title,
    this.description = '',
    required this.colorHex,
    required this.iconKey,
    this.frequency = HabitFrequency.daily,
    this.reminderTime,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final int colorHex;
  final String iconKey;
  final HabitFrequency frequency;
  final String? reminderTime;
  final DateTime createdAt;

  // Hive mendukung Map; tidak perlu TypeAdapter atau code generation.
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'colorHex': colorHex,
    'iconKey': iconKey,
    'frequency': frequency.name,
    'reminderTime': reminderTime,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Habit.fromMap(Map<String, dynamic> map) {
    final frequencyName = map['frequency'] as String? ?? 'daily';
    return Habit(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      colorHex: map['colorHex'] as int,
      iconKey: map['iconKey'] as String,
      frequency: HabitFrequency.values.firstWhere(
        (frequency) => frequency.name == frequencyName,
      ),
      reminderTime: map['reminderTime'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
