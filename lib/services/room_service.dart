import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/json_helpers.dart';
import '../models/room_model.dart';

class RoomService {
  final SupabaseClient _client;

  static const String _selectWithHouse =
      '*, house!room_house_id_fkey(*, users!house_owner_id_fkey(*))';

  RoomService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  Future<List<RoomModel>> getRooms({int? houseId, RoomStatus? status}) async {
    try {
      var query = _client
          .from(SupabaseConstants.roomTable)
          .select(_selectWithHouse);

      if (houseId != null) {
        query = query.eq('house_id', houseId);
      }
      if (status != null) {
        query = query.eq('status', status.name);
      }

      final response = await query.order('room_number', ascending: true);
      return (response as List).mapToModel(RoomModel.fromJson);
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to load rooms.', code: e.code, cause: e);
    } catch (e) {
      throw ServiceException('Failed to load rooms.', cause: e);
    }
  }

  Future<RoomModel?> getRoomById(int roomId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.roomTable)
          .select(_selectWithHouse)
          .eq('room_id', roomId)
          .maybeSingle();

      if (response == null) return null;
      return RoomModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load room details.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load room details.', cause: e);
    }
  }

  Future<RoomModel> createRoom(RoomModel room) async {
    try {
      final response = await _client
          .from(SupabaseConstants.roomTable)
          .insert(room.toJson(includeId: false))
          .select(_selectWithHouse)
          .single();

      return RoomModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to create room.', code: e.code, cause: e);
    } catch (e) {
      throw ServiceException('Failed to create room.', cause: e);
    }
  }

  Future<RoomModel> updateRoom(RoomModel room) async {
    try {
      final response = await _client
          .from(SupabaseConstants.roomTable)
          .update(room.toJson(includeId: false))
          .eq('room_id', room.roomId)
          .select(_selectWithHouse)
          .single();

      return RoomModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to update room.', code: e.code, cause: e);
    } catch (e) {
      throw ServiceException('Failed to update room.', cause: e);
    }
  }

  Future<void> updateRoomStatus(int roomId, RoomStatus status) async {
    try {
      await _client
          .from(SupabaseConstants.roomTable)
          .update({'status': status.name})
          .eq('room_id', roomId);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to update room status.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to update room status.', cause: e);
    }
  }

  Future<void> deleteRoom(int roomId) async {
    try {
      await _client
          .from(SupabaseConstants.roomTable)
          .delete()
          .eq('room_id', roomId);
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to delete room.', code: e.code, cause: e);
    } catch (e) {
      throw ServiceException('Failed to delete room.', cause: e);
    }
  }
}
