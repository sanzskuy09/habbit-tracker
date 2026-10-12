import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/models/habit_log.dart';
import 'package:habit_tracker/services/habit_streak.dart';
import 'package:habit_tracker/utils/habit_date.dart';

import 'support/habit_fixture.dart';

HabitLog logOn(DateTime date, {String id = 'read'}) =>
    HabitLog(id: '$id:${HabitDate.key(date)}', habitId: id, completedAt: date);

void main() {
  final daily = habitFixture(
    frequency: HabitFrequency.daily,
    createdAt: DateTime(2026, 1, 1),
  );
  final today = DateTime(2026, 10, 9, 12);

  test('Empty history has no streak', () {
    expect(HabitStreak.current(daily, [], today), 0);
  });

  test('Today adds exactly one to consecutive daily completions', () {
    final logs = [logOn(DateTime(2026, 10, 7)), logOn(DateTime(2026, 10, 8))];
    expect(HabitStreak.current(daily, logs, today), 2);
    logs.add(logOn(today));
    expect(HabitStreak.current(daily, logs, today), 3);
  });

  test('A missed scheduled day breaks the streak', () {
    final logs = [logOn(DateTime(2026, 10, 7)), logOn(today)];
    expect(HabitStreak.current(daily, logs, today), 1);
    expect(HabitStreak.current(daily, [logs.first], today), 0);
  });

  test(
    'Duplicate times, unordered logs and other habits cannot inflate streak',
    () {
      final logs = [
        logOn(today),
        logOn(DateTime(2026, 10, 8, 23, 59)),
        logOn(DateTime(2026, 10, 8, 1)),
        logOn(today, id: 'other'),
      ];
      expect(HabitStreak.current(daily, logs, today), 2);
    },
  );

  test('Future completions are ignored', () {
    expect(
      HabitStreak.current(daily, [logOn(DateTime(2026, 10, 10))], today),
      0,
    );
  });

  test('Dates before creation do not count', () {
    final newHabit = habitFixture(
      frequency: HabitFrequency.daily,
      createdAt: today,
    );
    final logs = [logOn(DateTime(2026, 10, 8)), logOn(today)];
    expect(HabitStreak.current(newHabit, logs, today), 1);
    expect(HabitStreak.isScheduled(newHabit, DateTime(2026, 10, 8)), isFalse);
  });

  test('Weekdays skip Saturday/Sunday without breaking the streak', () {
    final habit = habitFixture(createdAt: DateTime(2026, 10, 1));
    final logs = [logOn(DateTime(2026, 10, 8)), logOn(DateTime(2026, 10, 9))];
    expect(HabitStreak.current(habit, logs, DateTime(2026, 10, 10)), 2);
    expect(HabitStreak.current(habit, logs, DateTime(2026, 10, 12)), 2);
    logs.add(logOn(DateTime(2026, 10, 12)));
    expect(HabitStreak.current(habit, logs, DateTime(2026, 10, 12)), 3);
    expect(HabitStreak.current(habit, logs, DateTime(2026, 10, 13)), 3);
    expect(HabitStreak.current(habit, logs, DateTime(2026, 10, 14)), 0);
  });

  test('Weekend streak follows consecutive scheduled weekend days', () {
    final habit = habitFixture(
      frequency: HabitFrequency.weekends,
      createdAt: DateTime(2026, 10, 1),
    );
    final logs = [
      logOn(DateTime(2026, 10, 3)),
      logOn(DateTime(2026, 10, 4)),
      logOn(DateTime(2026, 10, 10)),
    ];
    expect(HabitStreak.current(habit, logs, DateTime(2026, 10, 10)), 3);
    expect(HabitStreak.current(habit, logs, DateTime(2026, 10, 12)), 0);
  });

  test('Year and leap-month boundaries follow calendar days', () {
    final habit = habitFixture(
      frequency: HabitFrequency.daily,
      createdAt: DateTime(2023, 1, 1),
    );
    expect(
      HabitStreak.current(habit, [
        logOn(DateTime(2025, 12, 31)),
        logOn(DateTime(2026, 1, 1)),
      ], DateTime(2026, 1, 1)),
      2,
    );
    expect(
      HabitStreak.current(habit, [
        logOn(DateTime(2024, 2, 28)),
        logOn(DateTime(2024, 2, 29)),
        logOn(DateTime(2024, 3, 1)),
      ], DateTime(2024, 3, 1)),
      3,
    );
    expect(HabitDate.previous(DateTime(2024, 3, 1)), DateTime(2024, 2, 29));
  });

  test(
    'Changing frequency uses the current schedule without rewriting history',
    () {
      final weekdays = habitFixture(createdAt: DateTime(2026, 10, 1));
      final logs = [
        logOn(DateTime(2026, 10, 9)),
        logOn(DateTime(2026, 10, 10)),
        logOn(DateTime(2026, 10, 12)),
      ];
      expect(HabitStreak.current(weekdays, logs, DateTime(2026, 10, 12)), 2);
      expect(logs, hasLength(3));
    },
  );
}
