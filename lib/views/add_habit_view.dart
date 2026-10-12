import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../controllers/habit_controller.dart';
import 'widgets/habit_appearance.dart';
import 'widgets/habit_card.dart';

class AddHabitView extends StatefulWidget {
  const AddHabitView({super.key, this.habit});

  final Habit? habit;

  @override
  State<AddHabitView> createState() => _AddHabitViewState();
}

class _AddHabitViewState extends State<AddHabitView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _iconKey = 'book';
  int _colorHex = HabitAppearance.colors.keys.first;
  HabitFrequency _frequency = HabitFrequency.daily;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  bool _saving = false;
  late final String _habitId;
  late final DateTime _createdAt;

  bool get _isEditing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    _habitId = habit?.id ?? const Uuid().v4();
    _createdAt = habit?.createdAt ?? context.read<HabitController>().now;
    if (habit == null) return;
    _titleController.text = habit.title;
    _descriptionController.text = habit.description;
    _iconKey = habit.iconKey;
    _colorHex = habit.colorHex;
    _frequency = habit.frequency;
    _reminderEnabled = habit.reminderTime != null;
    if (habit.reminderTime != null) {
      final parts = habit.reminderTime!.split(':');
      _reminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
  }

  // HH:mm adalah format data. Tampilan jam memakai locale dari MaterialApp.
  String get _formattedTime =>
      '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (!mounted || time == null) return;
    setState(() => _reminderTime = time);
  }

  Future<void> _saveHabit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final habit = _buildHabit();
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await context.read<HabitController>().updateHabit(habit);
      } else {
        await context.read<HabitController>().createHabit(habit);
      }
      if (!mounted) return;
      // PopScope dibuka kembali setelah penulisan berhasil.
      setState(() => _saving = false);
      Navigator.of(context).pop(habit);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Habit gagal disimpan. Isianmu tetap ada, silakan coba lagi.',
          ),
        ),
      );
    }
  }

  Habit _buildHabit({bool preview = false}) => Habit(
    id: _habitId,
    title: preview && _titleController.text.trim().isEmpty
        ? 'Kebiasaan barumu'
        : _titleController.text.trim(),
    description: _descriptionController.text.trim(),
    colorHex: _colorHex,
    iconKey: _iconKey,
    frequency: _frequency,
    reminderTime: _reminderEnabled ? _formattedTime : null,
    createdAt: _createdAt,
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = _buildHabit(preview: true);

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? 'Edit habit' : 'Tambah habit')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: AbsorbPointer(
                absorbing: _saving,
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        _isEditing
                            ? 'Sesuaikan rutinitasmu.'
                            : 'Mulai kebiasaan baik.',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Buat target kecil yang mudah kamu ulangi.'),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const Key('habit-title'),
                        controller: _titleController,
                        maxLength: 60,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nama kebiasaan',
                          hintText: 'Misalnya, baca buku 15 menit',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama kebiasaan wajib diisi.';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('habit-description'),
                        controller: _descriptionController,
                        maxLength: 240,
                        minLines: 2,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi (opsional)',
                          hintText: 'Apa target yang ingin kamu capai?',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pilih ikon',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: HabitAppearance.icons.entries.map((entry) {
                          return ChoiceChip(
                            avatar: Icon(entry.value, size: 18),
                            label: Text(HabitAppearance.iconLabels[entry.key]!),
                            selected: _iconKey == entry.key,
                            onSelected: (_) =>
                                setState(() => _iconKey = entry.key),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Pilih warna',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: HabitAppearance.colors.entries.map((entry) {
                          final selected = _colorHex == entry.key;
                          return Semantics(
                            button: true,
                            selected: selected,
                            label: 'Warna ${entry.value}',
                            child: Tooltip(
                              message: entry.value,
                              child: InkWell(
                                key: Key('color-${entry.key}'),
                                borderRadius: BorderRadius.circular(24),
                                onTap: () =>
                                    setState(() => _colorHex = entry.key),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Color(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                  child: selected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<HabitFrequency>(
                        initialValue: _frequency,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Frekuensi',
                        ),
                        items: HabitFrequency.values
                            .map(
                              (frequency) => DropdownMenuItem(
                                value: frequency,
                                child: Text(frequency.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _frequency = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              title: const Text('Pengingat'),
                              subtitle: const Text(
                                'Pilih jam untuk rutinitasmu.',
                              ),
                              value: _reminderEnabled,
                              onChanged: (value) =>
                                  setState(() => _reminderEnabled = value),
                            ),
                            if (_reminderEnabled)
                              ListTile(
                                leading: const Icon(Icons.schedule_rounded),
                                title: const Text('Waktu pengingat'),
                                subtitle: Text(_reminderTime.format(context)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _pickTime,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Pratinjau habit',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      HabitCard(habit: preview),
                      const SizedBox(height: 16),
                      const Text(
                        'Habit disimpan di perangkat ini. Pengingat mengikuti frekuensi dan zona waktu perangkat. Izinkan notifikasi saat menyimpan. Di Android, pengingat dapat terlambat saat mode hemat daya.',
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveHabit,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Menyimpan…' : 'Simpan habit'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
