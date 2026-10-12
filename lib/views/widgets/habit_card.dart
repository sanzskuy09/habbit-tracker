import 'package:flutter/material.dart';

import '../../models/habit.dart';
import 'habit_appearance.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    this.trailing,
    this.footer,
    this.streak,
    this.isCompleted = false,
  });

  final Habit habit;
  final Widget? trailing;
  final Widget? footer;
  final int? streak;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.colorHex);
    final textTheme = Theme.of(context).textTheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isCompleted ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isCompleted
                ? color.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AnimatedSwitcher(
                    duration: duration,
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : HabitAppearance.iconFor(habit.iconKey),
                      key: ValueKey(isCompleted),
                      color: color,
                    ),
                  ),
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
                          Text(
                            habit.frequency.label,
                            style: textTheme.labelMedium,
                          ),
                          if (streak != null)
                            Text(
                              '$streak hari terjadwal beruntun',
                              style: textTheme.labelMedium,
                            ),
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
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}
