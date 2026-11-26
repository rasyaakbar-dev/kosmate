import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/formatters.dart';
import '../core/utils/supabase_helpers.dart';
import '../models/booking_model.dart';

class BookingService {
  final SupabaseClient _client = supabase;

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

  Future<List<BookingModel>> getBookingsByUser(int userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.bookingTable)
          .select(
            '*, users!booking_user_id_fkey(*), room!booking_room_id_fkey(*, house!room_house_id_fkey(*, users!house_owner_id_fkey(*)))',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).mapToModel(BookingModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load user bookings.', cause: e);
    }
  }

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

      // NOTE: Room status transitions (occupied/available) are handled by the
      // DB trigger `handle_booking_status_change`. No redundant client-side
      // update needed here to avoid double-write race conditions.

      return BookingModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to update booking status.', cause: e);
    }
  }

  /// Check whether a tenant booking is eligible for cancellation.
  /// Rules:
  /// 1. Cannot cancel during the 1st month of tenancy.
  /// 2. Cannot cancel if near end of the month (7 to 14 days before month-end).
  ({bool allowed, String? reason}) checkCancellationEligibility(
    BookingModel booking,
  ) {
    final now = DateTime.now();
    final tenancyStart = booking.requestDate;

    // Rule 1: 1st month check
    final daysSinceStart = now.difference(tenancyStart).inDays;
    if (daysSinceStart < 30) {
      return (
        allowed: false,
        reason:
            'Cancellation is not permitted during your 1st month of tenancy. Your tenancy commenced on ${Formatters.formatDate(tenancyStart)}.',
      );
    }

    // Rule 2: Near end of the month (7-14 days before month-end)
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemainingInMonth = lastDayOfMonth - now.day;
    if (daysRemainingInMonth >= 7 && daysRemainingInMonth <= 14) {
      return (
        allowed: false,
        reason:
            'Cancellation is locked 7 to 14 days before the end of the month ($daysRemainingInMonth days remaining in this month). Please plan your cancellation outside this cutoff window.',
      );
    }

    return (allowed: true, reason: null);
  }

  Future<BookingModel> cancelTenantBooking({
    required BookingModel booking,
  }) async {
    final eligibility = checkCancellationEligibility(booking);
    if (!eligibility.allowed) {
      throw ValidationException(
        eligibility.reason ??
            'Cancellation is not allowed under current lease policy.',
      );
    }

    return await updateBookingStatus(
      bookingId: booking.bookingId,
      status: BookingStatus.cancelled,
      roomId: booking.roomId,
    );
  }

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
