import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/controllers/habit_controller.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/services/local_reminder_service.dart';
import 'package:habit_tracker/services/reminder_plan.dart';
import 'package:habit_tracker/services/reminder_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'support/fake_habit_service.dart';
import 'support/fake_reminder_backend.dart';
import 'support/habit_fixture.dart';

class ControlledReminders implements ReminderService {
  Completer<void>? holdNext;
  int active = 0;
  int maxActive = 0;
  List<Habit> latest = [];
  @override
  Future<String?> sync(
    List<Habit> habits, {
    bool requestPermission = false,
  }) async {
    active++;
    if (active > maxActive) maxActive = active;
    final gate = holdNext;
    holdNext = null;
    if (gate != null) await gate.future;
    latest = habits;
    active--;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz_data.initializeTimeZones);
  test(
    'Resume and edit are serialized; final reminders use the latest habit',
    () async {
      final storage = FakeHabitService()..habits['read'] = habitFixture();
      final reminders = ControlledReminders();
      final controller = HabitController(
        service: storage,
        reminders: reminders,
        monitorDate: false,
      );
      addTearDown(controller.dispose);
      await controller.load();
      final gate = Completer<void>();
      reminders.holdNext = gate;
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      final edit = controller.updateHabit(habitFixture(title: 'Judul terbaru'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.habits.single.title, 'Judul terbaru');
      gate.complete();
      await edit;
      expect(reminders.maxActive, 1);
      expect(reminders.latest.single.title, 'Judul terbaru');
      expect(controller.reminderBusy, isFalse);
    },
  );
  final now = DateTime.utc(2026, 10, 9, 13, 15); // Jumat 20:15 WIB

  test(
    'Daily time equal to now rolls to tomorrow, disabled reminders are skipped',
    () {
      final plans = ReminderPlan.build([
        habitFixture(frequency: HabitFrequency.daily),
        habitFixture(id: 'off', reminderTime: null),
      ], tz.TZDateTime.from(now, tz.getLocation('Asia/Jakarta')));
      expect(plans, hasLength(1));
      expect(plans.single.weekday, isNull);
      expect(
        plans.single.at,
        tz.TZDateTime(tz.getLocation('Asia/Jakarta'), 2026, 10, 10, 20, 15),
      );
    },
  );

  test(
    'Work/weekend reminders repeat only on selected days with collision-free IDs',
    () {
      final plans = ReminderPlan.build([
        habitFixture(id: 'work'),
        habitFixture(id: 'rest', frequency: HabitFrequency.weekends),
      ], tz.TZDateTime.from(now, tz.getLocation('Asia/Jakarta')));
      expect(plans, hasLength(7));
      expect(plans.map((plan) => plan.id).toSet(), hasLength(7));
      expect(
        plans
            .where((plan) => plan.habit.id == 'work')
            .map((plan) => plan.weekday),
        [1, 2, 3, 4, 5],
      );
      expect(
        plans
            .where((plan) => plan.habit.id == 'rest')
            .map((plan) => plan.at.day),
        [10, 11],
      );
      expect(plans.every((plan) => plan.at.isAfter(now)), isTrue);
      expect(plans.firstWhere((plan) => plan.weekday == 5).at.day, 16);
    },
  );

  test(
    'Calendar scheduling preserves local hour across spring and autumn DST',
    () {
      final zone = tz.getLocation('America/New_York');
      for (final date in [
        tz.TZDateTime(zone, 2026, 3, 7, 21),
        tz.TZDateTime(zone, 2026, 10, 31, 21),
      ]) {
        final plan = ReminderPlan.build([
          habitFixture(frequency: HabitFrequency.daily, reminderTime: '08:00'),
        ], date).single;
        expect(plan.at.hour, 8);
        expect(plan.at.day, date.day == 31 ? 1 : 8);
        expect(plan.at.timeZoneOffset, isNot(date.timeZoneOffset));
      }
    },
  );

  test('Invalid times and more than 64 requests are reported explicitly', () {
    for (final time in ['25:00', '12:60', '8:00', 'oops']) {
      expect(
        () => ReminderPlan.build([
          habitFixture(reminderTime: time),
        ], tz.TZDateTime.utc(2026)),
        throwsA(isA<ReminderException>()),
      );
    }
    expect(
      () => ReminderPlan.build([
        for (var i = 0; i < 13; i++) habitFixture(id: '$i'),
      ], tz.TZDateTime.utc(2026)),
      throwsA(isA<ReminderException>()),
    );
    expect(
      ReminderPlan.build([
        for (var i = 0; i < 64; i++)
          habitFixture(id: '$i', frequency: HabitFrequency.daily),
      ], tz.TZDateTime.utc(2026)),
      hasLength(64),
    );
  });

  test(
    'Startup reconciles without prompting; edit/disable/delete removes stale requests',
    () async {
      final backend = FakeReminderBackend();
      final reminders = LocalReminderService(
        backend: backend,
        clock: () => now,
      );
      await reminders.sync([habitFixture()]);
      expect(backend.pending, hasLength(5));
      expect(backend.permissionRequests, 0);
      await reminders.sync([
        habitFixture(
          title: 'Judul baru',
          frequency: HabitFrequency.weekends,
          reminderTime: '09:00',
        ),
      ]);
      expect(backend.pending, hasLength(2));
      expect(
        backend.pending.every(
          (plan) => plan.at.hour == 9 && plan.habit.title == 'Judul baru',
        ),
        isTrue,
      );
      await reminders.sync([habitFixture(reminderTime: null)]);
      expect(backend.pending, isEmpty);
      await reminders.sync([]);
      expect(backend.pending, isEmpty);
    },
  );

  test(
    'Permission denial clears schedules and explicit retry can grant permission',
    () async {
      final backend = FakeReminderBackend()..allowed = false;
      final reminders = LocalReminderService(
        backend: backend,
        clock: () => now,
      );
      expect(
        await reminders.sync([habitFixture()]),
        contains('Izinkan notifikasi'),
      );
      expect(backend.permissionRequests, 0);
      expect(backend.pending, isEmpty);
      backend.grantOnRequest = true;
      expect(
        await reminders.sync([habitFixture()], requestPermission: true),
        isNull,
      );
      expect(backend.permissionRequests, 1);
      expect(backend.pending, hasLength(5));
    },
  );

  test('Partial scheduling failure removes partial requests', () async {
    final backend = FakeReminderBackend()..failAtId = 2;
    await expectLater(
      LocalReminderService(
        backend: backend,
        clock: () => now,
      ).sync([habitFixture()]),
      throwsStateError,
    );
    expect(backend.pending, isEmpty);
    expect(backend.cancelCalls, 2);
  });

  test(
    'Changing timezone rebuilds at same wall-clock time in device zone',
    () async {
      final backend = FakeReminderBackend();
      final reminders = LocalReminderService(
        backend: backend,
        clock: () => now,
      );
      await reminders.sync([habitFixture(frequency: HabitFrequency.daily)]);
      expect(backend.pending.single.at.location.name, 'Asia/Jakarta');
      backend.zone = 'Asia/Tokyo';
      await reminders.sync([habitFixture(frequency: HabitFrequency.daily)]);
      expect(backend.pending.single.at.location.name, 'Asia/Tokyo');
      expect(backend.pending.single.at.hour, 20);
      expect(backend.pending.single.at.minute, 15);
    },
  );

  test(
    'Controller commits data even if notification permission is denied or scheduling fails',
    () async {
      final storage = FakeHabitService();
      final backend = FakeReminderBackend()..allowed = false;
      final controller = HabitController(
        service: storage,
        reminders: LocalReminderService(backend: backend, clock: () => now),
        clock: () => now,
        monitorDate: false,
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.createHabit(habitFixture());
      expect(storage.habits, hasLength(1));
      expect(controller.habits, hasLength(1));
      expect(controller.reminderWarning, isNotNull);
      expect(controller.loadError, isNull);
      backend.allowed = true;
      backend.failAtId = 2;
      await controller.retryReminders();
      expect(
        controller.reminderWarning,
        contains('Data habit tetap tersimpan'),
      );
      backend.failAtId = null;
      await controller.retryReminders();
      expect(controller.reminderWarning, isNull);
      expect(controller.busy, isFalse);
      expect(controller.reminderBusy, isFalse);
      expect(backend.pending, hasLength(5));
      final cancelCalls = backend.cancelCalls;
      await controller.toggleToday(controller.habits.single);
      expect(backend.cancelCalls, cancelCalls); // centang tidak mengubah jadwal
      await controller.deleteHabit('read');
      expect(backend.pending, isEmpty);
    },
  );

  test(
    'A failed database write never changes the active notification schedule',
    () async {
      final storage = FakeHabitService()..habits['read'] = habitFixture();
      final backend = FakeReminderBackend();
      final controller = HabitController(
        service: storage,
        reminders: LocalReminderService(backend: backend, clock: () => now),
        monitorDate: false,
      );
      addTearDown(controller.dispose);
      await controller.load();
      final cancelCalls = backend.cancelCalls;
      storage.failSave = true;
      await expectLater(
        controller.updateHabit(habitFixture(reminderTime: null)),
        throwsStateError,
      );
      expect(backend.cancelCalls, cancelCalls);
      expect(backend.pending, hasLength(5));
    },
  );

  test(
    'Resume refreshes permissions and timezone without permission prompt',
    () async {
      final storage = FakeHabitService()..habits['read'] = habitFixture();
      final backend = FakeReminderBackend()..allowed = false;
      final controller = HabitController(
        service: storage,
        reminders: LocalReminderService(backend: backend, clock: () => now),
        clock: () => now,
        monitorDate: false,
      );
      addTearDown(controller.dispose);
      await controller.load();
      backend.allowed = true;
      backend.zone = 'Asia/Tokyo';
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(controller.reminderWarning, isNull);
      expect(backend.pending.first.at.location.name, 'Asia/Tokyo');
      expect(backend.permissionRequests, 0);
    },
  );
}
