import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/habit_service.dart';
import 'services/hive_habit_service.dart';
import 'theme/app_theme.dart';
import 'views/dashboard_view.dart';

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key, this.habitService});

  // Tes dapat memasukkan service pengganti tanpa membuka database perangkat.
  final HabitService? habitService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Routine Craft',
      debugShowCheckedModeBanner: false,
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      home: _DatabaseBootstrap(habitService: habitService),
    );
  }
}

class _DatabaseBootstrap extends StatefulWidget {
  const _DatabaseBootstrap({this.habitService});

  final HabitService? habitService;

  @override
  State<_DatabaseBootstrap> createState() => _DatabaseBootstrapState();
}

class _DatabaseBootstrapState extends State<_DatabaseBootstrap> {
  late Future<HabitService> _serviceFuture;
  HabitService? _ownedService;

  @override
  void initState() {
    super.initState();
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
    // Service yang diinjeksi dimiliki pemanggil; hanya tutup milik bootstrap.
    if (_ownedService != null) unawaited(_ownedService!.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HabitService>(
      future: _serviceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
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
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return DashboardView(habitService: snapshot.data!);
      },
    );
  }
}
