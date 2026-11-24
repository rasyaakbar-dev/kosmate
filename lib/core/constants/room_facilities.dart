import 'package:flutter/material.dart';

class RoomFacilities {
  static const options = [
    'Single Bed',
    'Wardrobe',
    'Study Desk',
    'Chair',
    'Air Conditioning',
    'Fan',
    'Private Bathroom',
    'Shared Bathroom',
    'Water Heater',
    'Wi-Fi',
    'Television',
    'Refrigerator',
    'Kitchen Access',
    'Laundry Access',
    'Parking',
  ];

  static const _icons = {
    'single bed': Icons.bed_outlined,
    'wardrobe': Icons.door_sliding_outlined,
    'study desk': Icons.desk_outlined,
    'chair': Icons.chair_outlined,
    'air conditioning': Icons.ac_unit,
    'fan': Icons.toys,
    'private bathroom': Icons.shower_outlined,
    'shared bathroom': Icons.shower_outlined,
    'water heater': Icons.hot_tub_outlined,
    'wi-fi': Icons.wifi,
    'television': Icons.tv_outlined,
    'refrigerator': Icons.kitchen_outlined,
    'kitchen access': Icons.kitchen_outlined,
    'laundry access': Icons.local_laundry_service_outlined,
    'parking': Icons.local_parking_outlined,
  };

  static List<String> parse(String? value) {
    if (value == null || value.trim().isEmpty) return const [];

    final facilities = <String>[];
    final seen = <String>{};
    for (final item in value.split(RegExp(r'[,;\n]'))) {
      final trimmed = item.trim();
      if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) continue;

      final known = options.where(
        (option) => option.toLowerCase() == trimmed.toLowerCase(),
      );
      facilities.add(known.isNotEmpty ? known.first : trimmed);
    }
    return facilities;
  }

  static IconData iconFor(String facility) =>
      _icons[facility.toLowerCase()] ?? Icons.check_circle_outline;
}
