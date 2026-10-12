import 'package:habit_tracker/services/local_reminder_service.dart';
import 'package:habit_tracker/services/reminder_plan.dart';
import 'package:timezone/timezone.dart' as tz;

class FakeReminderBackend implements ReminderBackend {
  String zone = 'Asia/Jakarta';
  bool allowed = true;
  bool grantOnRequest = false;
  int cancelCalls = 0;
  int permissionRequests = 0;
  int? failAtId;
  final pending = <HabitReminder>[];

  @override
  Future<void> initialize() async {}
  @override
  Future<tz.Location> location() async => tz.getLocation(zone);
  @override
  Future<bool> permission({required bool request}) async {
    if (request) {
      permissionRequests++;
      if (grantOnRequest) allowed = true;
    }
    return allowed;
  }

  @override
  Future<void> cancelPending() async {
    cancelCalls++;
    pending.clear();
  }

  @override
  Future<void> schedule(HabitReminder reminder) async {
    if (reminder.id == failAtId) throw StateError('Scheduling failed');
    pending.add(reminder);
  }
}
