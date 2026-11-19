import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/supabase_helpers.dart';
import '../models/room_model.dart';

class RoomService {
  final SupabaseClient _client = supabase;

  /// Fetch rooms with optional house and status filtering
  Future<List<RoomModel>> getRooms({int? houseId, RoomStatus? status}) async {
    try {
      var query = _client
          .from(SupabaseConstants.roomTable)
          .select(
            '*, house!room_house_id_fkey(*, users!house_owner_id_fkey(*))',
          );

      if (houseId != null) {
        query = query.eq('house_id', houseId);
      }
      if (status != null) {
        query = query.eq('status', status.name);
      }

      final response = await query.order('room_number', ascending: true);
      return (response as List).mapToModel(RoomModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load rooms.', cause: e);
    }
  }

  /// Fetch single room by ID
  Future<RoomModel?> getRoomById(int roomId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.roomTable)
          .select(
            '*, house!room_house_id_fkey(*, users!house_owner_id_fkey(*))',
          )
          .eq('room_id', roomId)
          .maybeSingle();

      if (response == null) return null;
      return RoomModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to load room details.', cause: e);
    }
  }

  /// Create a new room
  Future<RoomModel> createRoom(RoomModel room) async {
    try {
      final response = await _client
          .from(SupabaseConstants.roomTable)
          .insert(room.toJson(includeId: false))
          .select(
            '*, house!room_house_id_fkey(*, users!house_owner_id_fkey(*))',
          )
          .single();

      return RoomModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to create room.', cause: e);
    }
  }

  /// Update an existing room
  Future<RoomModel> updateRoom(RoomModel room) async {
    try {
      final response = await _client
          .from(SupabaseConstants.roomTable)
          .update(room.toJson(includeId: false))
          .eq('room_id', room.roomId)
          .select(
            '*, house!room_house_id_fkey(*, users!house_owner_id_fkey(*))',
          )
          .single();

      return RoomModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to update room.', cause: e);
    }
  }

  /// Quick status update for a room (e.g., mark as occupied or available)
  Future<void> updateRoomStatus(int roomId, RoomStatus status) async {
    try {
      await _client
          .from(SupabaseConstants.roomTable)
          .update({'status': status.name})
          .eq('room_id', roomId);
    } catch (e) {
      throw ServiceException('Failed to update room status.', cause: e);
    }
  }

  /// Delete a room
  Future<void> deleteRoom(int roomId) async {
    try {
      await _client
          .from(SupabaseConstants.roomTable)
          .delete()
          .eq('room_id', roomId);
    } catch (e) {
      throw ServiceException('Failed to delete room.', cause: e);
    }
  }
}
