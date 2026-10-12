import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit.dart';
import 'reminder_plan.dart';
import 'reminder_service.dart';

/// Adapter ini memisahkan platform channel dari alur rekonsiliasi yang dites.
abstract interface class ReminderBackend {
  Future<void> initialize();
  Future<tz.Location> location();
  Future<bool> permission({required bool request});
  Future<void> cancelPending();
  Future<void> schedule(HabitReminder reminder);
}

class LocalReminderService implements ReminderService {
  LocalReminderService({ReminderBackend? backend, DateTime Function()? clock})
    : _backend = backend ?? PluginReminderBackend(),
      _clock = clock ?? DateTime.now;

  final ReminderBackend _backend;
  final DateTime Function() _clock;

  @override
  Future<String?> sync(
    List<Habit> habits, {
    bool requestPermission = false,
  }) async {
    await _backend.initialize();
    // Semua pending notification aplikasi ini adalah pengingat habit. Bangun
    // ulang dari Hive agar edit/hapus/restart tidak menyisakan jadwal lama.
    await _backend.cancelPending();
    if (!habits.any((habit) => habit.reminderTime != null)) return null;
    final location = await _backend.location();
    final plan = ReminderPlan.build(
      habits,
      tz.TZDateTime.from(_clock(), location),
    );
    if (!await _backend.permission(request: requestPermission)) {
      return 'Pengingat belum aktif. Izinkan notifikasi; jika pernah ditolak, buka Pengaturan perangkat → Routine Craft → Notifikasi, lalu coba lagi.';
    }
    try {
      for (final reminder in plan) {
        await _backend.schedule(reminder);
      }
    } catch (_) {
      // Hindari mengklaim seluruh pengingat aktif jika hanya sebagian berhasil.
      await _backend.cancelPending();
      rethrow;
    }
    return null;
  }
}

class PluginReminderBackend implements ReminderBackend {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      throw const ReminderException('Pengingat tersedia di Android dan iOS.');
    }
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<tz.Location> location() async {
    final deviceZone = await FlutterTimezone.getLocalTimezone();
    // Dibaca ulang pada resume supaya perubahan zona perangkat diterapkan.
    return tz.getLocation(deviceZone.identifier);
  }

  @override
  Future<bool> permission({required bool request}) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      if (request) await android.requestNotificationsPermission();
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()!;
    if (request) {
      await ios.requestPermissions(alert: true, sound: true, badge: false);
    }
    final settings = await ios.checkPermissions();
    return settings?.isAlertEnabled ?? false;
  }

  @override
  Future<void> cancelPending() => _plugin.cancelAllPendingNotifications();

  @override
  Future<void> schedule(HabitReminder reminder) => _plugin.zonedSchedule(
    reminder.id,
    'Waktunya ${reminder.habit.title}',
    'Langkah kecil hari ini untuk rutinitas yang lebih baik.',
    reminder.at,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_reminders',
        'Pengingat habit',
        channelDescription: 'Pengingat sesuai jam dan frekuensi kebiasaan',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    ),
    // Tidak memerlukan izin exact alarm. Android dapat menunda saat hemat daya.
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: reminder.weekday == null
        ? DateTimeComponents.time
        : DateTimeComponents.dayOfWeekAndTime,
    payload: reminder.habit.id,
  );
}
