/// Disiapkan sesuai PRD untuk riwayat penyelesaian pada phase berikutnya.
class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.completedAt,
  });

  final String id;
  final String habitId;
  final DateTime completedAt;
}
