import 'package:flutter/material.dart';

import '../constants/room_facilities.dart';
import '../theme/app_theme.dart';

class RoomFacilitiesCard extends StatelessWidget {
  final String? facilities;

  const RoomFacilitiesCard({super.key, required this.facilities});

  @override
  Widget build(BuildContext context) {
    final items = RoomFacilities.parse(facilities);
    if (items.isEmpty) {
      return const Text(
        'No facilities listed',
        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((facility) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                RoomFacilities.iconFor(facility),
                color: AppTheme.accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                facility,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
