import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/house_model.dart';
import '../../../models/room_model.dart';

class HouseCard extends StatelessWidget {
  final HouseModel house;
  final bool showOwnerInfo;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HouseCard({
    super.key,
    required this.house,
    this.showOwnerInfo = false,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final roomService = sl.room;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 58,
                      height: 58,
                      color: AppTheme.borderLight,
                      child:
                          house.thumbnailUrl != null &&
                              house.thumbnailUrl!.trim().isNotEmpty
                          ? Image.network(
                              house.thumbnailUrl!.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.home_work_outlined,
                                color: AppTheme.textSubtle,
                              ),
                            )
                          : const Icon(
                              Icons.home_work_outlined,
                              color: AppTheme.textSubtle,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // House info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          house.houseName,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foregroundColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          house.houseAddress,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (showOwnerInfo) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Owner: ${house.owner?.name ?? "Owner #${house.ownerId}"}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSubtle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Options Menu
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppTheme.textMuted,
                    ),
                    onSelected: (action) {
                      if (action == 'details') {
                        onTap();
                      } else if (action == 'edit') {
                        onEdit();
                      } else if (action == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 18,
                              color: AppTheme.accentColor,
                            ),
                            SizedBox(width: 8),
                            Text('View Details & Rooms'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppTheme.textMuted,
                            ),
                            SizedBox(width: 8),
                            Text('Edit House'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppTheme.destructiveColor,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete House',
                              style: TextStyle(
                                color: AppTheme.destructiveColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 18, color: AppTheme.surfaceLight),

              // Room Summary
              FutureBuilder<List<RoomModel>>(
                future: roomService.getRooms(houseId: house.houseId),
                builder: (context, roomSnap) {
                  if (roomSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: LinearProgressIndicator());
                  }
                  final rooms = roomSnap.data ?? [];
                  if (rooms.isEmpty) {
                    return const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppTheme.textSubtle,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'No rooms added to this house yet.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSubtle,
                          ),
                        ),
                      ],
                    );
                  }

                  final availableCount = rooms
                      .where((r) => r.status == RoomStatus.available)
                      .length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${rooms.length} Rooms total ($availableCount available)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const Text(
                        'Manage >',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
