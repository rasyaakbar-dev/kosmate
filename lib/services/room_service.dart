import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../models/room_model.dart';

class RoomService {
  final SupabaseClient _client = supabase;

  /// Fetch rooms with optional house and status filtering
  Future<List<RoomModel>> getRooms({int? houseId, RoomStatus? status}) async {
    var query = _client
        .from(SupabaseConstants.roomTable)
        .select('*, house!room_house_id_fkey(*, users!house_owner_id_fkey(*))');

    if (houseId != null) {
      query = query.eq('house_id', houseId);
    }
    if (status != null) {
      query = query.eq('status', status.name);
    }

    final response = await query.order('room_number', ascending: true);

    return (response as List)
        .map((json) => RoomModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch single room by ID
  Future<RoomModel?> getRoomById(int roomId) async {
    final response = await _client
        .from(SupabaseConstants.roomTable)
        .select('*, house!room_house_id_fkey(*, users!house_owner_id_fkey(*))')
        .eq('room_id', roomId)
        .maybeSingle();

    if (response == null) return null;
    return RoomModel.fromJson(response);
  }

  /// Create a new room
  Future<RoomModel> createRoom(RoomModel room) async {
    final response = await _client
        .from(SupabaseConstants.roomTable)
        .insert(room.toJson(includeId: false))
        .select('*, house!room_house_id_fkey(*, users!house_owner_id_fkey(*))')
        .single();

    return RoomModel.fromJson(response);
  }

  /// Update an existing room
  Future<RoomModel> updateRoom(RoomModel room) async {
    final response = await _client
        .from(SupabaseConstants.roomTable)
        .update(room.toJson(includeId: false))
        .eq('room_id', room.roomId)
        .select('*, house!room_house_id_fkey(*, users!house_owner_id_fkey(*))')
        .single();

    return RoomModel.fromJson(response);
  }

  /// Quick status update for a room (e.g., mark as occupied or available)
  Future<void> updateRoomStatus(int roomId, RoomStatus status) async {
    await _client
        .from(SupabaseConstants.roomTable)
        .update({'status': status.name})
        .eq('room_id', roomId);
  }

  /// Delete a room
  Future<void> deleteRoom(int roomId) async {
    await _client
        .from(SupabaseConstants.roomTable)
        .delete()
        .eq('room_id', roomId);
  }
}
