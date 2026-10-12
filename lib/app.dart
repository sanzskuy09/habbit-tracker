import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'controllers/habit_controller.dart';
import 'services/habit_service.dart';
import 'services/hive_habit_service.dart';
import 'services/local_reminder_service.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';
import 'views/dashboard_view.dart';

class HabitTrackerApp extends StatefulWidget {
  const HabitTrackerApp({
    super.key,
    this.habitService,
    this.reminderService,
    this.clock,
  });

  // Dependency injection memungkinkan tes memakai service/tanggal terkontrol.
  final HabitService? habitService;
  final ReminderService? reminderService;
  final DateTime Function()? clock;

  @override
  State<HabitTrackerApp> createState() => _HabitTrackerAppState();
}

class _HabitTrackerAppState extends State<HabitTrackerApp> {
  late Future<HabitService> _serviceFuture;
  HabitService? _ownedService;
  late final ReminderService _reminders;

  @override
  void initState() {
    super.initState();
    _reminders =
        widget.reminderService ?? LocalReminderService(clock: widget.clock);
    _serviceFuture = widget.habitService != null
        ? Future.value(widget.habitService!)
        : _openDatabase();
  }

  Future<HabitService> _openDatabase() async {
    final service = await HiveHabitService.open();
    if (mounted) {
      _ownedService = service;
    } else {
      await service.close();
    }
    return service;
  }

  @override
  void dispose() {
    if (_ownedService != null) unawaited(_ownedService!.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HabitService>(
      future: _serviceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AppShell(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        if (snapshot.hasError) {
          return _AppShell(
            home: Scaffold(
              appBar: AppBar(title: const Text('Routine Craft')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Penyimpanan lokal belum bisa dibuka.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _serviceFuture = _openDatabase()),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        // Provider berada di atas MaterialApp/Navigator sehingga semua route
        // (Dashboard, form, kalender) mengakses controller yang sama.
        return ChangeNotifierProvider(
          create: (_) => HabitController(
            service: snapshot.data!,
            reminders: _reminders,
            clock: widget.clock,
          )..load(),
          child: const _AppShell(home: DashboardView()),
        );
      },
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Routine Craft',
    debugShowCheckedModeBanner: false,
    locale: const Locale('id'),
    supportedLocales: const [Locale('id')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.light,
    home: home,
  );
}
