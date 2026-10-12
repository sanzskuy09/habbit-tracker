import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/controllers/habit_controller.dart';
import 'package:habit_tracker/models/habit.dart';

import 'support/fake_habit_service.dart';
import 'support/habit_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHabitService service;
  late HabitController controller;
  late DateTime now;
  setUp(() {
    service = FakeHabitService();
    now = DateTime(2026, 10, 9, 23, 59);
    service.habits['read'] = habitFixture(createdAt: DateTime(2026, 10, 1));
    controller = HabitController(
      service: service,
      clock: () => now,
      monitorDate: false,
    );
  });
  tearDown(() => controller.dispose());

  test(
    'Load shares stored habits and logs, retry recovers from errors',
    () async {
      service.failRead = true;
      await controller.load();
      expect(controller.loadError, isNotNull);
      service.failRead = false;
      await controller.load();
      expect(controller.loadError, isNull);
      expect(controller.habits, hasLength(1));
      expect(controller.todayHabits, hasLength(1));
    },
  );

  test(
    'Complete and undo update counts and streak after successful storage',
    () async {
      await controller.load();
      await controller.toggleToday(controller.habits.single);
      expect(controller.completedToday, 1);
      expect(controller.streak(controller.habits.single), 1);
      expect(service.logs, hasLength(1));
      await controller.toggleToday(controller.habits.single);
      expect(controller.completedToday, 0);
      expect(controller.streak(controller.habits.single), 0);
      expect(service.logs, isEmpty);
    },
  );

  test('Failed completion leaves state untouched and can be retried', () async {
    await controller.load();
    service.failCompletion = true;
    await expectLater(
      controller.toggleToday(controller.habits.single),
      throwsStateError,
    );
    expect(controller.completedToday, 0);
    expect(controller.logs, isEmpty);
    expect(controller.busy, isFalse);
    service.failCompletion = false;
    await controller.toggleToday(controller.habits.single);
    expect(controller.completedToday, 1);
  });

  test(
    'Pending write rejects duplicate operations without optimistic changes',
    () async {
      await controller.load();
      service.completionGate = Completer<void>();
      final pending = controller.toggleToday(controller.habits.single);
      expect(controller.busy, isTrue);
      expect(controller.completedToday, 0);
      await expectLater(
        controller.toggleToday(controller.habits.single),
        throwsStateError,
      );
      service.completionGate!.complete();
      await pending;
      expect(service.logs, hasLength(1));
      expect(controller.completedToday, 1);
    },
  );

  test(
    'Date rollover resets today but preserves history and schedule streak',
    () async {
      await controller.load();
      await controller.toggleToday(controller.habits.single);
      now = DateTime(2026, 10, 10);
      controller.refreshDate();
      expect(controller.today, DateTime(2026, 10, 10));
      expect(controller.completedToday, 0);
      expect(controller.todayHabits, isEmpty);
      expect(controller.logs, hasLength(1));
      expect(controller.streak(controller.habits.single), 1);
    },
  );

  test(
    'Unscheduled habit cannot be completed and progress denominator excludes it',
    () async {
      service.habits['weekend'] = habitFixture(
        id: 'weekend',
        frequency: HabitFrequency.weekends,
      );
      await controller.load();
      expect(controller.todayHabits, hasLength(1));
      await expectLater(
        controller.toggleToday(controller.habits.last),
        throwsStateError,
      );
      expect(controller.logs, isEmpty);
    },
  );

  test(
    'Deleting a habit removes its logs from shared state and storage',
    () async {
      await controller.load();
      await controller.toggleToday(controller.habits.single);
      await controller.deleteHabit('read');
      expect(controller.habits, isEmpty);
      expect(controller.logs, isEmpty);
      expect(service.logs, isEmpty);
    },
  );

  test('Month and year rollover update the local date correctly', () async {
    now = DateTime(2026, 12, 31, 23, 59);
    controller.refreshDate();
    now = DateTime(2027, 1, 1);
    controller.refreshDate();
    expect(controller.today, DateTime(2027, 1, 1));
  });

  test('Resuming after background checks the current date', () async {
    await controller.load();
    now = DateTime(2026, 10, 12);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(controller.today, DateTime(2026, 10, 12));
    expect(controller.todayHabits, hasLength(1));
  });
}
