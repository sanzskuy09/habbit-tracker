import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/services/local_reminder_service.dart';

import 'support/habit_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'checkPermissions') {
        return {'isEnabled': true, 'isAlertEnabled': true};
      }
      if ([
        'initialize',
        'areNotificationsEnabled',
        'requestNotificationsPermission',
        'requestPermissions',
      ].contains(call.method)) {
        return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      timezone,
      (_) async => {'identifier': 'Asia/Jakarta'},
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(timezone, null);
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Android adapter sends timezone, repeating schedule, icon and inexact mode to native API',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
      final service = LocalReminderService(
        clock: () => DateTime.utc(2026, 10, 9, 13),
      );
      await service.sync([
        habitFixture(frequency: HabitFrequency.daily),
      ], requestPermission: true);
      expect(calls.map((call) => call.method), [
        'initialize',
        'cancelAllPendingNotifications',
        'requestNotificationsPermission',
        'areNotificationsEnabled',
        'zonedSchedule',
      ]);
      expect(calls.first.arguments['defaultIcon'], 'ic_notification');
      final schedule = calls.last.arguments as Map;
      expect(schedule['timeZoneName'], 'Asia/Jakarta');
      expect(schedule['scheduledDateTime'], '2026-10-09T20:15:00');
      expect(
        schedule['matchDateTimeComponents'],
        DateTimeComponents.time.index,
      );
      expect(
        schedule['platformSpecifics']['scheduleMode'],
        'inexactAllowWhileIdle',
      );
      expect(schedule['payload'], 'read');
    },
  );

  test(
    'iOS adapter defers permission prompt and sends weekly recurrence',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      FlutterLocalNotificationsPlatform.instance =
          IOSFlutterLocalNotificationsPlugin();
      final service = LocalReminderService(
        clock: () => DateTime.utc(2026, 10, 9, 13),
      );
      await service.sync([habitFixture(frequency: HabitFrequency.weekends)]);
      final init = calls.first.arguments as Map;
      expect(init['requestAlertPermission'], isFalse);
      expect(init['requestSoundPermission'], isFalse);
      expect(calls.any((call) => call.method == 'requestPermissions'), isFalse);
      final schedules = calls
          .where((call) => call.method == 'zonedSchedule')
          .toList();
      expect(schedules, hasLength(2));
      expect(
        schedules.every(
          (call) =>
              call.arguments['matchDateTimeComponents'] ==
              DateTimeComponents.dayOfWeekAndTime.index,
        ),
        isTrue,
      );
      expect(
        schedules.first.arguments['scheduledDateTime'],
        '2026-10-10T20:15:00',
      );
      calls.clear();
      await service.sync([habitFixture()], requestPermission: true);
      expect(calls.any((call) => call.method == 'requestPermissions'), isTrue);
    },
  );
}
