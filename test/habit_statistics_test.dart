import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/models/habit_log.dart';
import 'package:habit_tracker/services/habit_statistics.dart';

import 'support/habit_fixture.dart';

HabitLog log(String id, int day) =>
    HabitLog(id: '$id:$day', habitId: id, completedAt: DateTime(2026, 10, day));

void main() {
  test('Empty and no-schedule periods have zero counts without NaN', () {
    final empty = HabitStatistics.calculate(
      habits: [],
      logs: [],
      today: DateTime(2026, 10, 9),
      dayCount: 30,
    );
    expect(empty.days, hasLength(30));
    expect(empty.days.first.date, DateTime(2026, 9, 10));
    expect(empty.days.last.date, DateTime(2026, 10, 9));
    expect(empty.percentage, 0);
    final weekend = HabitStatistics.calculate(
      habits: [habitFixture(frequency: HabitFrequency.weekends)],
      logs: [],
      today: DateTime(2026, 10, 9),
      dayCount: 1,
    );
    expect(weekend.scheduled, 0);
    expect(weekend.completed, 0);
  });

  test(
    'Creation date excludes prior days and percentage weights each schedule',
    () {
      final stats = HabitStatistics.calculate(
        habits: [
          habitFixture(
            id: 'old',
            frequency: HabitFrequency.daily,
            createdAt: DateTime(2026, 10, 8),
          ),
          habitFixture(id: 'new', frequency: HabitFrequency.daily),
        ],
        logs: [log('old', 7), log('old', 8), log('new', 9)],
        today: DateTime(2026, 10, 9),
        dayCount: 3,
      );
      expect(stats.days.map((day) => day.scheduled), [0, 1, 2]);
      expect(stats.scheduled, 3);
      expect(stats.completed, 2);
      expect(stats.percentage, closeTo(200 / 3, 0.0001));
    },
  );

  test(
    'Weekdays/weekends, duplicates, orphan logs and future logs are filtered',
    () {
      final stats = HabitStatistics.calculate(
        habits: [
          habitFixture(
            id: 'daily',
            frequency: HabitFrequency.daily,
            createdAt: DateTime(2026, 10, 1),
          ),
          habitFixture(id: 'work', createdAt: DateTime(2026, 10, 1)),
          habitFixture(
            id: 'rest',
            frequency: HabitFrequency.weekends,
            createdAt: DateTime(2026, 10, 1),
          ),
        ],
        logs: [
          log('daily', 3),
          log('daily', 3),
          log('work', 3),
          log('rest', 3),
          log('work', 9),
          log('rest', 9),
          log('daily', 10),
          log('deleted', 9),
        ],
        today: DateTime(2026, 10, 9),
        dayCount: 7,
      );
      expect(stats.scheduled, 14); // 7 + 5 + 2
      expect(stats.completed, 3);
      expect(stats.days.first.completed, 2);
      expect(stats.days.last.completed, 1);
      expect(stats.percentage, closeTo(300 / 14, 0.0001));
    },
  );

  test('Editing schedule changes analytics without changing raw history', () {
    final logs = [log('read', 3), log('read', 9)];
    final edited = HabitStatistics.calculate(
      habits: [habitFixture(createdAt: DateTime(2026, 10, 1))],
      logs: logs,
      today: DateTime(2026, 10, 9),
      dayCount: 7,
    );
    expect(edited.scheduled, 5);
    expect(edited.completed, 1);
    expect(logs, hasLength(2));
  });

  test('Calendar range handles leap years and year boundaries', () {
    final leap = HabitStatistics.calculate(
      habits: [],
      logs: [],
      today: DateTime(2024, 3, 1),
      dayCount: 3,
    );
    expect(leap.days.map((day) => day.date), [
      DateTime(2024, 2, 28),
      DateTime(2024, 2, 29),
      DateTime(2024, 3, 1),
    ]);
    final year = HabitStatistics.calculate(
      habits: [],
      logs: [],
      today: DateTime(2027, 1, 1),
      dayCount: 2,
    );
    expect(year.days.first.date, DateTime(2026, 12, 31));
    expect(
      () => HabitStatistics.calculate(
        habits: [],
        logs: [],
        today: DateTime(2026),
        dayCount: 0,
      ),
      throwsArgumentError,
    );
  });
}
