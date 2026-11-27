import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/formatters.dart';
import '../core/utils/json_helpers.dart';
import '../models/booking_model.dart';

class BookingService {
  final SupabaseClient _client;

  static const String _selectWithRelations =
      '*, users!booking_user_id_fkey(*), room!booking_room_id_fkey(*, house!room_house_id_fkey(*))';

  BookingService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

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
          .select(_selectWithRelations)
          .single();

      return BookingModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to submit booking request.',
        code: e.code,
        cause: e,
      );
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
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load user bookings.',
        code: e.code,
        cause: e,
      );
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
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load bookings for owner.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load bookings for owner.', cause: e);
    }
  }

  Future<List<BookingModel>> getBookingsByRoomIds(
    List<int> roomIds, {
    BookingStatus? status,
  }) async {
    if (roomIds.isEmpty) return const [];
    try {
      var query = _client
          .from(SupabaseConstants.bookingTable)
          .select('*, users!booking_user_id_fkey(*)')
          .inFilter('room_id', roomIds);

      if (status != null) {
        query = query.eq('status', status.name);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).mapToModel(BookingModel.fromJson);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load room bookings.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load room bookings.', cause: e);
    }
  }

  Future<BookingModel?> getLatestApprovedBookingForRoom(int roomId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.bookingTable)
          .select('*, users!booking_user_id_fkey(*)')
          .eq('room_id', roomId)
          .eq('status', BookingStatus.approved.name)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return BookingModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load room tenant booking.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load room tenant booking.', cause: e);
    }
  }

  Future<BookingModel> updateBookingStatus({
    required int bookingId,
    required BookingStatus status,
  }) async {
    try {
      // Room status transitions are handled by DB trigger `handle_booking_status_change`.
      final response = await _client
          .from(SupabaseConstants.bookingTable)
          .update({'status': status.name})
          .eq('booking_id', bookingId)
          .select(_selectWithRelations)
          .single();

      return BookingModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to update booking status.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to update booking status.', cause: e);
    }
  }

  /// Checks whether a tenant booking is eligible for cancellation:
  /// 1. Cannot cancel during the first 30 days of tenancy.
  /// 2. Cannot cancel 7 to 14 days before month-end.
  ({bool allowed, String? reason}) checkCancellationEligibility(
    BookingModel booking,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tenancyStart = DateTime(
      booking.requestDate.year,
      booking.requestDate.month,
      booking.requestDate.day,
    );

    final daysSinceStart = today.difference(tenancyStart).inDays;
    if (daysSinceStart < 30) {
      return (
        allowed: false,
        reason:
            'Cancellation is not permitted during your 1st month of tenancy. Your tenancy commenced on ${Formatters.formatDate(booking.requestDate)}.',
      );
    }

    final lastDayOfMonth = DateTime(today.year, today.month + 1, 0).day;
    final daysRemainingInMonth = lastDayOfMonth - today.day;
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

    return updateBookingStatus(
      bookingId: booking.bookingId,
      status: BookingStatus.cancelled,
    );
  }

  Stream<List<BookingModel>> streamBookingsByUser(int userId) {
    return _client
        .from(SupabaseConstants.bookingTable)
        .stream(primaryKey: ['booking_id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .asyncMap((_) => getBookingsByUser(userId));
  }
}
