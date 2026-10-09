import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/services/hive_habit_service.dart';

import 'support/habit_fixture.dart';

void expectHabit(Habit actual, Habit expected) {
  expect(actual.id, expected.id);
  expect(actual.title, expected.title);
  expect(actual.description, expected.description);
  expect(actual.colorHex, expected.colorHex);
  expect(actual.iconKey, expected.iconKey);
  expect(actual.frequency, expected.frequency);
  expect(actual.reminderTime, expected.reminderTime);
  expect(actual.createdAt, expected.createdAt);
}

void main() {
  late Directory directory;
  late HiveHabitService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('habit_tracker_test_');
    service = await HiveHabitService.open(directory: directory.path);
  });

  tearDown(() async {
    await service.close();
    await directory.delete(recursive: true);
  });

  Future<void> reopen() async {
    await service.close();
    service = await HiveHabitService.open(directory: directory.path);
  }

  test('A new database starts empty', () async {
    expect(await service.getHabits(), isEmpty);
  });

  test('Create persists every field across close and reopen', () async {
    final habit = habitFixture();
    await service.createHabit(habit);
    await reopen();
    final saved = (await service.getHabits()).single;
    expectHabit(saved, habit);
    expect(await File('${directory.path}/habits_v1.hive').exists(), isTrue);
  });

  test(
    'Edit updates the same record and can clear an optional reminder',
    () async {
      final original = habitFixture();
      await service.createHabit(original);
      final edited = habitFixture(
        title: 'Jalan sore',
        description: 'Keliling taman',
        colorHex: 0xFF417CAC,
        iconKey: 'walk',
        frequency: HabitFrequency.weekends,
        reminderTime: null,
      );
      await service.updateHabit(edited);
      await reopen();
      final saved = (await service.getHabits()).single;
      expectHabit(saved, edited);
      expect(saved.id, original.id);
      expect(saved.createdAt, original.createdAt);
    },
  );

  test('Delete persists and leaves other habits untouched', () async {
    await service.createHabit(habitFixture());
    final other = habitFixture(id: 'water', title: 'Minum air');
    await service.createHabit(other);
    await service.deleteHabit('read');
    await reopen();
    expectHabit((await service.getHabits()).single, other);
    await service.deleteHabit('water');
    await reopen();
    expect(await service.getHabits(), isEmpty);
  });

  test(
    'Duplicate IDs and missing edits cannot silently overwrite data',
    () async {
      final original = habitFixture();
      await service.createHabit(original);
      await expectLater(
        service.createHabit(habitFixture(title: 'Duplikat')),
        throwsStateError,
      );
      await expectLater(
        service.updateHabit(habitFixture(id: 'missing')),
        throwsStateError,
      );
      await expectLater(service.deleteHabit('missing'), throwsStateError);
      await reopen();
      expectHabit((await service.getHabits()).single, original);
    },
  );

  test(
    'Invalid title and changed creation date leave stored data untouched',
    () async {
      await expectLater(
        service.createHabit(habitFixture(title: '   ')),
        throwsArgumentError,
      );
      final original = habitFixture();
      await service.createHabit(original);
      await expectLater(
        service.updateHabit(habitFixture(createdAt: DateTime(2026, 10, 10))),
        throwsArgumentError,
      );
      await reopen();
      expectHabit((await service.getHabits()).single, original);
    },
  );

  test('Reads are sorted newest first after reopening', () async {
    final older = habitFixture(id: 'older', createdAt: DateTime(2026, 10, 1));
    final newer = habitFixture(id: 'newer', createdAt: DateTime(2026, 10, 9));
    await service.createHabit(older);
    await service.createHabit(newer);
    await reopen();
    expect((await service.getHabits()).map((habit) => habit.id), [
      'newer',
      'older',
    ]);
  });
}
