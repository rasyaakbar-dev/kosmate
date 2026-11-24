import 'package:flutter/material.dart';

import '../constants/room_facilities.dart';
import '../theme/app_theme.dart';

class RoomFacilitiesSelector extends StatelessWidget {
  final List<String> selectedFacilities;
  final ValueChanged<List<String>> onChanged;

  const RoomFacilitiesSelector({
    super.key,
    required this.selectedFacilities,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final choices = <String>{
      ...RoomFacilities.options,
      ...selectedFacilities.where(
        (facility) => !RoomFacilities.options.any(
          (option) => option.toLowerCase() == facility.toLowerCase(),
        ),
      ),
    };

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: choices.map((facility) {
        final selected = selectedFacilities.any(
          (item) => item.toLowerCase() == facility.toLowerCase(),
        );
        return FilterChip(
          avatar: Icon(
            RoomFacilities.iconFor(facility),
            size: 18,
            color: selected ? AppTheme.accentColor : AppTheme.textMuted,
          ),
          label: Text(facility),
          selected: selected,
          onSelected: (enabled) {
            final next = [...selectedFacilities];
            if (enabled) {
              next.add(facility);
            } else {
              next.removeWhere(
                (item) => item.toLowerCase() == facility.toLowerCase(),
              );
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}
