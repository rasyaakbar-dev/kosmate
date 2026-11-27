import 'package:flutter/material.dart';

import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../models/room_model.dart';
import '../../houses/widgets/room_form_body.dart';

class AdminRoomFormScreen extends StatelessWidget {
  final RoomModel? room;
  final int? initialHouseId;

  const AdminRoomFormScreen({super.key, this.room, this.initialHouseId});

  bool get isEditing => room != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KosMateAppBar(
        title: isEditing ? 'Edit Room' : 'Add Room',
        showBackButton: true,
      ),
      body: RoomFormBody(
        room: room,
        initialHouseId: initialHouseId,
        roomTypeLabel: 'Room Type',
        roomTypeOptions: const [
          'Standard',
          'Deluxe',
          'VIP',
          'Studio',
          'Floor 1',
          'Floor 2',
          'Floor 3',
        ],
        allowDelete: true,
        onSaved: (_) => Navigator.pop(context, true),
        onDeleted: () => Navigator.pop(context, true),
      ),
    );
  }
}
