import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/habit_controller.dart';
import '../models/habit.dart';
import '../services/habit_streak.dart';
import '../theme/app_theme.dart';
import 'add_habit_view.dart';
import 'habit_history_view.dart';
import 'habit_statistics_view.dart';
import 'widgets/habit_card.dart';

enum _HabitAction { history, edit, delete }

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm(BuildContext context, {Habit? habit}) async {
    final saved = await Navigator.of(context).push<Habit>(
      MaterialPageRoute(builder: (_) => AddHabitView(habit: habit)),
    );
    if (!context.mounted || saved == null) return;
    // Controller sudah memperbarui daftar; tidak perlu baca ulang dari view.
    _showMessage(
      context,
      habit == null
          ? 'Habit berhasil ditambahkan.'
          : 'Perubahan berhasil disimpan.',
    );
  }

  Future<void> _deleteHabit(BuildContext context, Habit habit) async {
    final controller = context.read<HabitController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus habit?'),
        content: Text(
          '"${habit.title}" beserta riwayatnya akan dihapus dari perangkat ini.',
        ),
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
    if (!context.mounted || confirmed != true) return;
    try {
      await controller.deleteHabit(habit.id);
      if (context.mounted) _showMessage(context, 'Habit berhasil dihapus.');
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Habit gagal dihapus. Coba lagi.');
      }
    }
  }

  Future<void> _toggleToday(BuildContext context, Habit habit) async {
    try {
      await context.read<HabitController>().toggleToday(habit);
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Status belum bisa disimpan. Coba lagi.');
      }
    }
  }

  Widget _header(BuildContext context, HabitController controller) {
    final textTheme = Theme.of(context).textTheme;
    final total = controller.todayHabits.length;
    final completed = controller.completedToday;
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
        Text(
          MaterialLocalizations.of(context).formatFullDate(controller.today),
        ),
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
                'PROGRES HARI INI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$completed dari $total habit selesai',
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: total == 0 ? 0 : completed / total,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFCAE9A1),
                backgroundColor: Colors.white24,
                semanticsLabel: 'Progres hari ini',
                semanticsValue: '$completed dari $total',
              ),
              const SizedBox(height: 12),
              Text(
                '${controller.habits.length} habit tersimpan',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                total == 0
                    ? 'Tidak ada jadwal untuk hari ini.'
                    : 'Setiap usaha kecil tetap berarti.',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        if (controller.reminderWarning != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Periksa pengingat',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(controller.reminderWarning!),
                  TextButton.icon(
                    onPressed: controller.busy || controller.reminderBusy
                        ? null
                        : controller.retryReminders,
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Izinkan / coba lagi'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Daftar kebiasaan',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Centang rutinitas hari ini. Buka menu untuk melihat riwayat atau mengelola habit.',
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HabitController>();
    final habits = controller.habits;
    final ready =
        !controller.loading && controller.loadError == null && !controller.busy;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Statistik',
            onPressed: ready
                ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HabitStatisticsView(),
                    ),
                  )
                : null,
            icon: const Icon(Icons.bar_chart_rounded),
          ),
        ],
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
            child: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : controller.loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            controller.loadError!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: controller.load,
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                    itemCount: habits.isEmpty ? 2 : habits.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _header(context, controller);
                      if (habits.isEmpty) {
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
                      final habit = habits[index - 1];
                      final done = controller.isCompleted(
                        habit.id,
                        controller.today,
                      );
                      final scheduled = HabitStreak.isScheduled(
                        habit,
                        controller.today,
                      );
                      return Padding(
                        key: ValueKey(habit.id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: HabitCard(
                          habit: habit,
                          isCompleted: done,
                          streak: controller.streak(habit),
                          footer: Row(
                            children: [
                              Checkbox(
                                key: Key('habit-check-${habit.id}'),
                                value: done,
                                semanticLabel:
                                    'Selesai hari ini: ${habit.title}',
                                onChanged: ready && (scheduled || done)
                                    ? (_) => _toggleToday(context, habit)
                                    : null,
                              ),
                              Expanded(
                                child: Text(
                                  done
                                      ? 'Selesai hari ini'
                                      : scheduled
                                      ? 'Tandai selesai hari ini'
                                      : 'Tidak dijadwalkan hari ini',
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<_HabitAction>(
                            key: Key('habit-menu-${habit.id}'),
                            tooltip: 'Kelola ${habit.title}',
                            enabled: ready,
                            onSelected: (action) {
                              switch (action) {
                                case _HabitAction.history:
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          HabitHistoryView(habitId: habit.id),
                                    ),
                                  );
                                case _HabitAction.edit:
                                  _openForm(context, habit: habit);
                                case _HabitAction.delete:
                                  _deleteHabit(context, habit);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: _HabitAction.history,
                                child: Text('Riwayat'),
                              ),
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
        onPressed: ready ? () => _openForm(context) : null,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah habit'),
      ),
    );
  }
}
