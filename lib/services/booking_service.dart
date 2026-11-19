import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/formatters.dart';
import '../core/utils/supabase_helpers.dart';
import '../models/booking_model.dart';
import '../models/room_model.dart';

class BookingService {
  final SupabaseClient _client = supabase;

  /// Submit a room booking request
  Future<BookingModel> createBooking({
    required int userId,
    required int roomId,
    required DateTime requestDate,
    String? notes,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.bookingTable)
          .insert({
            'user_id': userId,
            'room_id': roomId,
            'request_date': Formatters.toDateString(requestDate),
            'status': BookingStatus.pending.name,
            'notes': notes,
          })
          .select(
            '*, users!booking_user_id_fkey(*), room!booking_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .single();

      return BookingModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to submit booking request.', cause: e);
    }
  }

  /// Get all bookings requested by a specific tenant
  Future<List<BookingModel>> getBookingsByUser(int userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.bookingTable)
          .select(
            '*, users!booking_user_id_fkey(*), room!booking_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).mapToModel(BookingModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load user bookings.', cause: e);
    }
  }

  /// Get all bookings for rooms belonging to houses owned by a specific owner
  Future<List<BookingModel>> getBookingsForOwner(int ownerId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.bookingTable)
          .select(
            '*, users!booking_user_id_fkey(*), room!booking_room_id_fkey!inner(*, house!room_house_id_fkey!inner(*))',
          )
          .eq('room.house.owner_id', ownerId)
          .order('created_at', ascending: false);

      return (response as List).mapToModel(BookingModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load bookings for owner.', cause: e);
    }
  }

  /// Update booking status (e.g. approve, reject, cancel)
  /// If approved, optionally transitions room status to occupied
  Future<BookingModel> updateBookingStatus({
    required int bookingId,
    required BookingStatus status,
    int? roomId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.bookingTable)
          .update({'status': status.name})
          .eq('booking_id', bookingId)
          .select(
            '*, users!booking_user_id_fkey(*), room!booking_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .single();

      // If booking was approved and room_id provided, mark room as occupied
      if (status == BookingStatus.approved && roomId != null) {
        await _client
            .from(SupabaseConstants.roomTable)
            .update({'status': RoomStatus.occupied.name})
            .eq('room_id', roomId);
      }

      return BookingModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to update booking status.', cause: e);
    }
  }

  /// Realtime stream of bookings for a tenant
  Stream<List<BookingModel>> streamBookingsByUser(int userId) {
    return _client
        .from(SupabaseConstants.bookingTable)
        .stream(primaryKey: ['booking_id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .asyncMap((event) async {
          // Re-fetch with relational data for full model mapping
          return await getBookingsByUser(userId);
        });
  }
}
