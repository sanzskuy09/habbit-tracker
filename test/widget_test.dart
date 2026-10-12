import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/app.dart';
import 'package:provider/provider.dart';
import 'package:habit_tracker/views/dashboard_view.dart';
import 'package:habit_tracker/services/reminder_service.dart';
import 'package:habit_tracker/services/local_reminder_service.dart';
import 'package:habit_tracker/controllers/habit_controller.dart';
import 'package:habit_tracker/models/habit_log.dart';
import 'package:habit_tracker/views/habit_statistics_view.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:habit_tracker/views/habit_history_view.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/views/add_habit_view.dart';
import 'package:habit_tracker/views/widgets/habit_card.dart';

import 'support/fake_habit_service.dart';
import 'support/habit_fixture.dart';
import 'support/fake_reminder_backend.dart';

Future<void> openDashboard(
  WidgetTester tester,
  FakeHabitService service,
) async {
  await tester.pumpWidget(
    HabitTrackerApp(
      habitService: service,
      reminderService: const NoopReminderService(),
      clock: () => DateTime(2026, 10, 9, 12),
    ),
  );
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpAndSettle();
}

Future<void> openForm(WidgetTester tester, FakeHabitService service) async {
  await openDashboard(tester, service);
  await tester.tap(find.text('Tambah habit'));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> selectAction(WidgetTester tester, String id, String action) async {
  await scrollTo(tester, find.byKey(Key('habit-menu-$id')));
  await tester.tap(find.byKey(Key('habit-menu-$id')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(tz_data.initializeTimeZones);
  late FakeHabitService service;
  setUp(() => service = FakeHabitService());

  testWidgets('Dashboard starts empty without sample data', (tester) async {
    await openDashboard(tester, service);
    expect(find.text('Routine Craft'), findsOneWidget);
    expect(find.text('0 habit tersimpan'), findsOneWidget);
    expect(find.text('Belum ada habit'), findsOneWidget);
    expect(find.text('Baca buku'), findsNothing);
  });

  testWidgets('Blank and whitespace titles are rejected', (tester) async {
    await openForm(tester, service);
    await tester.tap(find.text('Simpan habit'));
    await tester.pumpAndSettle();
    expect(find.text('Nama kebiasaan wajib diisi.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('habit-title')), '   ');
    await tester.tap(find.text('Simpan habit'));
    await tester.pumpAndSettle();
    expect(find.byType(AddHabitView), findsOneWidget);
    expect(service.habits, isEmpty);
  });

  testWidgets('Save creates a trimmed habit and reloads the dashboard', (
    tester,
  ) async {
    await openForm(tester, service);
    await tester.enterText(
      find.byKey(const Key('habit-title')),
      '  Meditasi 10 menit  ',
    );
    await tester.tap(find.text('Simpan habit'));
    await tester.pumpAndSettle();
    expect(find.byType(AddHabitView), findsNothing);
    expect(find.text('1 habit tersimpan'), findsOneWidget);
    expect(find.text('Habit berhasil ditambahkan.'), findsOneWidget);
    await scrollTo(tester, find.text('Meditasi 10 menit'));
    expect(service.habits.values.single.title, 'Meditasi 10 menit');
  });

  testWidgets('Back cancels a draft without saving', (tester) async {
    await openForm(tester, service);
    await tester.enterText(
      find.byKey(const Key('habit-title')),
      'Target batal',
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(service.habits, isEmpty);
    expect(find.byType(AddHabitView), findsNothing);
  });

  testWidgets('Appearance and frequency selections are saved', (tester) async {
    await openForm(tester, service);
    await tester.enterText(
      find.byKey(const Key('habit-title')),
      'Olahraga pagi',
    );
    await tester.enterText(
      find.byKey(const Key('habit-description')),
      'Gerak selama 20 menit',
    );
    await scrollTo(tester, find.text('Olahraga'));
    await tester.tap(find.text('Olahraga'));
    const blue = 0xFF417CAC;
    await scrollTo(tester, find.byKey(const Key('color-$blue')));
    await tester.tap(find.byKey(const Key('color-$blue')));
    final dropdown = find.byType(DropdownButtonFormField<HabitFrequency>);
    await scrollTo(tester, dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Senin–Jumat').last);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byType(HabitCard));
    expect(
      tester.widget<HabitCard>(find.byType(HabitCard)).habit.iconKey,
      'fitness',
    );
    await tester.tap(find.text('Simpan habit'));
    await tester.pumpAndSettle();
    final saved = service.habits.values.single;
    expect(saved.description, 'Gerak selama 20 menit');
    expect(saved.iconKey, 'fitness');
    expect(saved.colorHex, blue);
    expect(saved.frequency, HabitFrequency.weekdays);
  });

  testWidgets('Edit prefills every field and preserves identity when saved', (
    tester,
  ) async {
    final original = habitFixture();
    service.habits[original.id] = original;
    await openDashboard(tester, service);
    await selectAction(tester, original.id, 'Edit');
    expect(find.text('Edit habit'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('habit-title')))
          .controller!
          .text,
      original.title,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('habit-description')))
          .controller!
          .text,
      original.description,
    );
    await tester.enterText(
      find.byKey(const Key('habit-title')),
      'Baca dua bab',
    );
    await scrollTo(tester, find.byType(HabitCard));
    final preview = tester.widget<HabitCard>(find.byType(HabitCard)).habit;
    expect(preview.reminderTime, original.reminderTime);
    expect(preview.frequency, original.frequency);
    expect(preview.colorHex, original.colorHex);
    expect(preview.iconKey, original.iconKey);
    await scrollTo(tester, find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.text('Simpan habit'));
    await tester.pumpAndSettle();
    final saved = service.habits.values.single;
    expect(saved.title, 'Baca dua bab');
    expect(saved.id, original.id);
    expect(saved.createdAt, original.createdAt);
    expect(saved.reminderTime, isNull);
    expect(find.text('Perubahan berhasil disimpan.'), findsOneWidget);
  });

  testWidgets('Back from edit leaves the original record unchanged', (
    tester,
  ) async {
    final original = habitFixture();
    service.habits[original.id] = original;
    await openDashboard(tester, service);
    await selectAction(tester, original.id, 'Edit');
    await tester.enterText(
      find.byKey(const Key('habit-title')),
      'Perubahan batal',
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(service.habits[original.id]!.toMap(), original.toMap());
  });

  testWidgets('Delete needs confirmation and reloads an empty dashboard', (
    tester,
  ) async {
    service.habits['read'] = habitFixture();
    await openDashboard(tester, service);
    await selectAction(tester, 'read', 'Hapus');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(service.habits, hasLength(1));
    await selectAction(tester, 'read', 'Hapus');
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(service.habits, isEmpty);
    expect(find.text('Belum ada habit'), findsOneWidget);
  });

  testWidgets('Read failures offer retry and recover without clearing habits', (
    tester,
  ) async {
    service.habits['read'] = habitFixture();
    service.failRead = true;
    await openDashboard(tester, service);
    expect(
      find.text('Kebiasaan belum bisa dimuat. Coba lagi.'),
      findsOneWidget,
    );
    service.failRead = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('1 habit tersimpan'), findsOneWidget);
  });

  testWidgets('Failed saves retain the input and can be retried', (
    tester,
  ) async {
    service.failSave = true;
    await openForm(tester, service);
    await tester.enterText(
      find.byKey(const Key('habit-title')),
      'Tetap belajar',
    );
    await tester.tap(find.text('Simpan habit'));
    await tester.pumpAndSettle();
    expect(find.byType(AddHabitView), findsOneWidget);
    expect(service.habits, isEmpty);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('habit-title')))
          .controller!
          .text,
      'Tetap belajar',
    );
    expect(
      find.text('Habit gagal disimpan. Isianmu tetap ada, silakan coba lagi.'),
      findsOneWidget,
    );
    service.failSave = false;
    await tester.tap(find.text('Simpan habit'));
    await tester.pumpAndSettle();
    expect(service.habits.values.single.title, 'Tetap belajar');
  });

  testWidgets(
    'Pending saves disable duplicate submission and back navigation',
    (tester) async {
      service.saveGate = Completer<void>();
      await openForm(tester, service);
      await tester.enterText(find.byKey(const Key('habit-title')), 'Satu kali');
      await tester.tap(find.text('Simpan habit'));
      await tester.pump();
      expect(find.text('Menyimpan…'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(find.byType(AddHabitView), findsOneWidget);
      expect(service.createCalls, 1);
      service.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AddHabitView), findsNothing);
      expect(service.habits, hasLength(1));
    },
  );

  testWidgets('Delete failures keep the original habit visible', (
    tester,
  ) async {
    service.habits['read'] = habitFixture();
    service.failDelete = true;
    await openDashboard(tester, service);
    await selectAction(tester, 'read', 'Hapus');
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(service.habits, hasLength(1));
    expect(find.text('Habit gagal dihapus. Coba lagi.'), findsOneWidget);
    expect(find.text('Baca buku'), findsOneWidget);
  });

  testWidgets('Reminder time picker still works with saving', (tester) async {
    await openForm(tester, service);
    await tester.enterText(find.byKey(const Key('habit-title')), 'Minum air');
    await scrollTo(tester, find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Waktu pengingat'));
    await tester.tap(find.text('Waktu pengingat'));
    await tester.pumpAndSettle();
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(TimePickerDialog)),
    );
    await tester.tap(find.text(localizations.okButtonLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan habit'));
    await tester.pumpAndSettle();
    expect(service.habits.values.single.reminderTime, '08:00');
  });

  testWidgets('Completion updates progress, streak and the history route', (
    tester,
  ) async {
    service.habits['read'] = habitFixture(createdAt: DateTime(2026, 10, 1));
    await openDashboard(tester, service);
    expect(find.text('0 dari 1 habit selesai'), findsOneWidget);
    await scrollTo(tester, find.byKey(const Key('habit-check-read')));
    await tester.tap(find.byKey(const Key('habit-check-read')));
    await tester.pumpAndSettle();
    expect(service.logs, hasLength(1));
    expect(find.text('1 hari terjadwal beruntun'), findsOneWidget);
    await selectAction(tester, 'read', 'Riwayat');
    expect(find.byType(HabitHistoryView), findsOneWidget);
    final cell = tester.widget<Container>(
      find.byKey(const Key('history-day-9')),
    );
    expect((cell.decoration as BoxDecoration).color, const Color(0xFF24786B));
    await scrollTo(tester, find.text('1 hari selesai pada bulan ini.'));
    expect(find.text('1 hari selesai pada bulan ini.'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('habit-check-read')));
    await tester.tap(find.byKey(const Key('habit-check-read')));
    await tester.pumpAndSettle();
    expect(service.logs, isEmpty);
    expect(find.text('0 hari terjadwal beruntun'), findsOneWidget);
  });

  testWidgets('Failed completion keeps the unchecked state and offers retry', (
    tester,
  ) async {
    service.habits['read'] = habitFixture();
    service.failCompletion = true;
    await openDashboard(tester, service);
    await scrollTo(tester, find.byKey(const Key('habit-check-read')));
    await tester.tap(find.byKey(const Key('habit-check-read')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Checkbox>(find.byKey(const Key('habit-check-read'))).value,
      isFalse,
    );
    expect(find.text('Status belum bisa disimpan. Coba lagi.'), findsOneWidget);
    expect(service.logs, isEmpty);
    service.failCompletion = false;
    await tester.tap(find.byKey(const Key('habit-check-read')));
    await tester.pumpAndSettle();
    expect(service.logs, hasLength(1));
  });

  testWidgets(
    'Unscheduled habit remains manageable but its checkbox is disabled',
    (tester) async {
      service.habits['weekend'] = habitFixture(
        id: 'weekend',
        frequency: HabitFrequency.weekends,
      );
      await openDashboard(tester, service);
      expect(find.text('0 dari 0 habit selesai'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('habit-check-weekend')));
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('habit-check-weekend')))
            .onChanged,
        isNull,
      );
      await selectAction(tester, 'weekend', 'Edit');
      expect(find.byType(AddHabitView), findsOneWidget);
    },
  );

  testWidgets('Automatic midnight rollover updates today without losing logs', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 9, 23, 59);
    service.habits['read'] = habitFixture(
      frequency: HabitFrequency.daily,
      createdAt: DateTime(2026, 10, 1),
    );
    await tester.pumpWidget(
      HabitTrackerApp(
        habitService: service,
        reminderService: const NoopReminderService(),
        clock: () => now,
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('habit-check-read')));
    await tester.tap(find.byKey(const Key('habit-check-read')));
    await tester.pumpAndSettle();
    now = DateTime(2026, 10, 10, 0, 0, 1);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Checkbox>(find.byKey(const Key('habit-check-read'))).value,
      isFalse,
    );
    expect(service.logs, hasLength(1));
    expect(find.text('1 hari terjadwal beruntun'), findsOneWidget);
  });

  for (final width in [320.0, 800.0]) {
    testWidgets(
      'Statistics chart and details work at width $width with enlarged text',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        service.habits['read'] = habitFixture(createdAt: DateTime(2026, 10, 1));
        await openDashboard(tester, service);
        await tester.tap(find.byTooltip('Statistik'));
        await tester.pumpAndSettle();
        expect(find.byType(HabitStatisticsView), findsOneWidget);
        await scrollTo(tester, find.byKey(const Key('statistics-scheduled')));
        expect(
          tester
              .widget<Text>(find.byKey(const Key('statistics-scheduled')))
              .data,
          '5',
        );
        await scrollTo(tester, find.byType(BarChart));
        expect(tester.takeException(), isNull);
        await scrollTo(tester, find.text('Rincian harian'));
        await tester.tap(find.text('Rincian harian'));
        await tester.pumpAndSettle();
        expect(find.text('0 dari 1 selesai · 0%'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      },
    );
    testWidgets('CRUD screens work at width $width with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      service.habits['read'] = habitFixture();
      await openDashboard(tester, service);
      await selectAction(tester, 'read', 'Edit');
      await scrollTo(tester, find.byType(HabitCard));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Baca buku'));
      expect(tester.takeException(), isNull);
      await selectAction(tester, 'read', 'Riwayat');
      expect(find.byType(HabitHistoryView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Statistics has an honest empty state and switches to 30 days', (
    tester,
  ) async {
    await openDashboard(tester, service);
    await tester.tap(find.byTooltip('Statistik'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('statistics-percentage'))).data,
      '—',
    );
    expect(find.byType(BarChart), findsNothing);
    await tester.tap(find.text('30 hari terakhir'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, '30 hari terakhir'),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets(
    'Statistics reflects shared logs immediately and chart switches range',
    (tester) async {
      service.habits['read'] = habitFixture(createdAt: DateTime(2026, 10, 1));
      service.logs['read:2026-10-08'] = HabitLog(
        id: 'read:2026-10-08',
        habitId: 'read',
        completedAt: DateTime(2026, 10, 8),
      );
      await openDashboard(tester, service);
      final controller = tester
          .element(find.byType(DashboardView))
          .read<HabitController>();
      await tester.tap(find.byTooltip('Statistik'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('statistics-percentage')))
            .data,
        '20%',
      );
      await controller.toggleToday(controller.habits.single);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('statistics-percentage')))
            .data,
        '40%',
      );
      await tester.tap(find.text('30 hari terakhir'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('statistics-scheduled'))).data,
        '7',
      );
      await scrollTo(tester, find.byType(BarChart));
      expect(
        tester.widget<BarChart>(find.byType(BarChart)).data.barGroups,
        hasLength(30),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Denied reminders show a separate warning and explicit retry enables them',
    (tester) async {
      service.habits['read'] = habitFixture();
      final backend = FakeReminderBackend()..allowed = false;
      await tester.pumpWidget(
        HabitTrackerApp(
          habitService: service,
          reminderService: LocalReminderService(
            backend: backend,
            clock: () => DateTime(2026, 10, 9, 12),
          ),
          clock: () => DateTime(2026, 10, 9, 12),
        ),
      );
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Izinkan / coba lagi'));
      expect(find.text('Periksa pengingat'), findsOneWidget);
      expect(backend.permissionRequests, 0);
      expect(service.habits, hasLength(1));
      backend.grantOnRequest = true;
      await tester.tap(find.text('Izinkan / coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Periksa pengingat'), findsNothing);
      expect(backend.pending, hasLength(5));
      expect(backend.permissionRequests, 1);
    },
  );
}
