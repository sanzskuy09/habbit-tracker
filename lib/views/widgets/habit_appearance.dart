import 'package:flutter/material.dart';

abstract final class HabitAppearance {
  static const icons = <String, IconData>{
    'book': Icons.menu_book_rounded,
    'water': Icons.water_drop_outlined,
    'walk': Icons.directions_walk_rounded,
    'fitness': Icons.fitness_center_rounded,
    'sleep': Icons.bedtime_outlined,
    'mindfulness': Icons.spa_outlined,
  };

  static const iconLabels = <String, String>{
    'book': 'Buku',
    'water': 'Air',
    'walk': 'Jalan',
    'fitness': 'Olahraga',
    'sleep': 'Tidur',
    'mindfulness': 'Relaksasi',
  };

  static const colors = <int, String>{
    0xFF24786B: 'Hijau',
    0xFF417CAC: 'Biru',
    0xFFAC672D: 'Oranye',
    0xFF8557AA: 'Ungu',
    0xFFB4536C: 'Merah muda',
  };

  static IconData iconFor(String key) => icons[key] ?? Icons.star_outline;
}
