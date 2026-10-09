import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/habit_service.dart';
import '../theme/app_theme.dart';
import 'add_habit_view.dart';
import 'widgets/habit_card.dart';

enum _HabitAction { edit, delete }

class DashboardView extends StatefulWidget {
  const DashboardView({super.key, required this.habitService});

  final HabitService habitService;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  List<Habit> _habits = [];
  bool _loading = true;
  String? _loadError;
  final _deletingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final habits = await widget.habitService.getHabits();
      if (!mounted) return;
      setState(() => _habits = habits);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Kebiasaan belum bisa dimuat. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Habit? habit}) async {
    final saved = await Navigator.of(context).push<Habit>(
      MaterialPageRoute(
        builder: (_) =>
            AddHabitView(habitService: widget.habitService, habit: habit),
      ),
    );
    if (!mounted || saved == null) return;
    await _loadHabits();
    if (!mounted) return;
    _showMessage(
      habit == null
          ? 'Habit berhasil ditambahkan.'
          : 'Perubahan berhasil disimpan.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteHabit(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus habit?'),
        content: Text('"${habit.title}" akan dihapus dari perangkat ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _deletingIds.contains(habit.id)) {
      return;
    }
    setState(() => _deletingIds.add(habit.id));
    try {
      await widget.habitService.deleteHabit(habit.id);
      if (!mounted) return;
      await _loadHabits();
      if (mounted) _showMessage('Habit berhasil dihapus.');
    } catch (_) {
      if (mounted) _showMessage('Habit gagal dihapus. Coba lagi.');
    } finally {
      if (mounted) setState(() => _deletingIds.remove(habit.id));
    }
  }

  Widget _header(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reminders = _habits
        .where((habit) => habit.reminderTime != null)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Langkah kecil,\nperubahan besar.',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Bangun rutinitas baik, satu hari demi satu hari.'),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KEBIASAANMU',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${_habits.length} habit tersimpan',
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$reminders dengan jam pengingat',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'Setiap usaha kecil tetap berarti.',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Daftar kebiasaan',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text('Kelola rutinitasmu lewat menu pada setiap habit.'),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.spa_outlined, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Routine Craft',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadHabits,
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                    itemCount: _habits.isEmpty ? 2 : _habits.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _header(context);
                      if (_habits.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.spa_outlined,
                                  size: 40,
                                  color: AppTheme.primary,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Belum ada habit',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tekan Tambah habit untuk mulai membangun rutinitasmu.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final habit = _habits[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: HabitCard(
                          habit: habit,
                          trailing: _deletingIds.contains(habit.id)
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : PopupMenuButton<_HabitAction>(
                                  key: Key('habit-menu-${habit.id}'),
                                  tooltip: 'Kelola ${habit.title}',
                                  onSelected: (action) {
                                    if (action == _HabitAction.edit) {
                                      _openForm(habit: habit);
                                    } else {
                                      _deleteHabit(habit);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: _HabitAction.edit,
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: _HabitAction.delete,
                                      child: Text('Hapus'),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah habit'),
      ),
    );
  }
}
