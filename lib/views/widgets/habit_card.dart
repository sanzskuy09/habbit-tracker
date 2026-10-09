import 'package:flutter/material.dart';

import '../../models/habit.dart';
import 'habit_appearance.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({super.key, required this.habit, this.trailing});

  final Habit habit;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.colorHex);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(HabitAppearance.iconFor(habit.iconKey), color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (habit.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(habit.description, style: textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(habit.frequency.label, style: textTheme.labelMedium),
                      if (habit.reminderTime != null)
                        Text(
                          '◷ ${habit.reminderTime}',
                          style: textTheme.labelMedium,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
