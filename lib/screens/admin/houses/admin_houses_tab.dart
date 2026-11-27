import 'package:flutter/material.dart';

import '../../../models/user_model.dart';
import '../../houses/widgets/house_rooms_manager_view.dart';
import '../rooms/admin_room_form_screen.dart';
import 'admin_house_form_screen.dart';

class AdminHousesTab extends StatelessWidget {
  final UserModel currentUser;
  final int? filterOwnerId;

  const AdminHousesTab({
    super.key,
    required this.currentUser,
    this.filterOwnerId,
  });

  bool get isOwnerMode => filterOwnerId != null;

  @override
  Widget build(BuildContext context) {
    return HouseRoomsManagerView(
      filterOwnerId: filterOwnerId,
      title: isOwnerMode
          ? 'Boarding Houses & Rooms'
          : 'Registered Boarding Houses',
      subtitle: 'Select a house to view and manage its rooms',
      searchHint: 'Search houses by name, address, or owner...',
      emptyHousesSubtitle:
          'Add the first boarding house to start managing rooms.',
      emptyRoomsSubtitle: 'Add rooms to make them available for tenants.',
      showOwnerInfo: true,
      onAddHouse: (ctx) async {
        final created = await Navigator.push<bool>(
          ctx,
          MaterialPageRoute(builder: (_) => const AdminHouseFormScreen()),
        );
        return (changed: created == true, selectHouse: null);
      },
      onEditHouse: (ctx, house) async {
        final updated = await Navigator.push<bool>(
          ctx,
          MaterialPageRoute(builder: (_) => AdminHouseFormScreen(house: house)),
        );
        return updated == true;
      },
      onAddRoom: (ctx, targetHouseId) async {
        final created = await Navigator.push<bool>(
          ctx,
          MaterialPageRoute(
            builder: (_) => AdminRoomFormScreen(initialHouseId: targetHouseId),
          ),
        );
        return created == true;
      },
      onEditRoom: (ctx, room) async {
        final updated = await Navigator.push<bool>(
          ctx,
          MaterialPageRoute(builder: (_) => AdminRoomFormScreen(room: room)),
        );
        return updated == true;
      },
    );
  }
}
