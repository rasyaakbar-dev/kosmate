import 'package:flutter/material.dart';

import '../../../models/house_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';
import '../../houses/house_form_screen.dart';
import '../../houses/widgets/house_rooms_manager_view.dart';
import 'room_detail_screen.dart';
import 'room_form_screen.dart';

class OwnerRoomsTab extends StatelessWidget {
  final UserModel currentUser;

  const OwnerRoomsTab({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return HouseRoomsManagerView(
      filterOwnerId: currentUser.userId,
      title: 'Boarding Houses',
      subtitle: 'Select a house to manage its rooms',
      searchHint: 'Search houses by name or address...',
      emptyHousesSubtitle:
          'Create your first boarding house to start managing its rooms and tenants.',
      emptyRoomsSubtitle:
          'Add your first room to make it available for tenants.',
      onAddHouse: (ctx) async {
        final created = await Navigator.push<HouseModel>(
          ctx,
          MaterialPageRoute(
            builder: (_) => HouseFormScreen(ownerId: currentUser.userId),
          ),
        );
        return (changed: created != null, selectHouse: created);
      },
      onEditHouse: (ctx, house) async {
        final updated = await Navigator.push<HouseModel>(
          ctx,
          MaterialPageRoute(
            builder: (_) =>
                HouseFormScreen(house: house, ownerId: currentUser.userId),
          ),
        );
        return updated != null;
      },
      onAddRoom: (ctx, targetHouseId) async {
        final created = await Navigator.push<RoomModel>(
          ctx,
          MaterialPageRoute(
            builder: (_) => RoomFormScreen(
              ownerId: currentUser.userId,
              houseId: targetHouseId,
            ),
          ),
        );
        return created != null;
      },
      onEditRoom: (ctx, room) async {
        final updated = await Navigator.push<RoomModel>(
          ctx,
          MaterialPageRoute(
            builder: (_) => RoomFormScreen(
              room: room,
              houseId: room.houseId,
              ownerId: currentUser.userId,
            ),
          ),
        );
        return updated != null;
      },
      onRoomTap: (ctx, room) async {
        final changed = await Navigator.push<bool>(
          ctx,
          MaterialPageRoute(
            builder: (_) =>
                RoomDetailScreen(room: room, currentUser: currentUser),
          ),
        );
        return changed == true;
      },
    );
  }
}
