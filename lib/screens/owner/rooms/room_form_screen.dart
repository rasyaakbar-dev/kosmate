import 'package:flutter/material.dart';

import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../models/house_model.dart';
import '../../../models/room_model.dart';
import '../../houses/house_form_screen.dart';
import '../../houses/widgets/room_form_body.dart';

class RoomFormScreen extends StatelessWidget {
  final RoomModel? room;
  final int? houseId;
  final int ownerId;

  const RoomFormScreen({
    super.key,
    this.room,
    this.houseId,
    required this.ownerId,
  });

  bool get isEditing => room != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: KosMateAppBar(
        title: isEditing ? 'Edit room' : 'Add room',
        showBackButton: true,
        showLogo: false,
      ),
      body: RoomFormBody(
        room: room,
        initialHouseId: houseId,
        ownerId: ownerId,
        roomTypeLabel: 'Floor',
        roomTypeOptions: const [
          'Floor 1',
          'Floor 2',
          'Floor 3',
          'Floor 4',
          'Floor 5',
        ],
        onCreateHouse: (ctx) => Navigator.push<HouseModel>(
          ctx,
          MaterialPageRoute(
            builder: (_) => HouseFormScreen(ownerId: ownerId),
          ),
        ),
        onSaved: (saved) => Navigator.pop(context, saved),
      ),
    );
  }
}
