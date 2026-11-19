import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/formatters.dart';
import '../core/utils/supabase_helpers.dart';
import '../models/complaint_model.dart';

class ComplaintService {
  final SupabaseClient _client = supabase;

  /// Submit a new tenant complaint / ticket
  Future<ComplaintModel> createComplaint({
    required int userId,
    required int roomId,
    required ComplaintCategory category,
    required String title,
    required String description,
    required ComplaintPriority priority,
    String? attachmentUrl,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.complaintTable)
          .insert({
            'user_id': userId,
            'room_id': roomId,
            'category': category.name,
            'title': title.trim(),
            'description': description.trim(),
            'priority': priority.name,
            'date': Formatters.toDateString(DateTime.now()),
            'status': ComplaintStatus.pending.name,
            'attachment_url': attachmentUrl,
          })
          .select(
            '*, users!complaint_user_id_fkey(*), room!complaint_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .single();

      return ComplaintModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to submit complaint.', cause: e);
    }
  }

  /// Fetch all complaints submitted by a tenant
  Future<List<ComplaintModel>> getComplaintsByUser(int userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.complaintTable)
          .select(
            '*, users!complaint_user_id_fkey(*), room!complaint_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).mapToModel(ComplaintModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load user complaints.', cause: e);
    }
  }

  /// Fetch all complaints for rooms owned by an owner
  Future<List<ComplaintModel>> getComplaintsForOwner(int ownerId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.complaintTable)
          .select(
            '*, users!complaint_user_id_fkey(*), room!complaint_room_id_fkey!inner(*, house!room_house_id_fkey!inner(*))',
          )
          .eq('room.house.owner_id', ownerId)
          .order('created_at', ascending: false);

      return (response as List).mapToModel(ComplaintModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load owner complaints.', cause: e);
    }
  }

  /// Owner responds to a complaint ticket
  Future<ComplaintModel> respondToComplaint({
    required int complaintId,
    required String responseText,
    required ComplaintStatus status,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.complaintTable)
          .update({'response': responseText.trim(), 'status': status.dbValue})
          .eq('complaint_id', complaintId)
          .select(
            '*, users!complaint_user_id_fkey(*), room!complaint_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .single();

      return ComplaintModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to respond to complaint.', cause: e);
    }
  }

  /// Realtime stream of complaints for a user
  Stream<List<ComplaintModel>> streamComplaintsByUser(int userId) {
    return _client
        .from(SupabaseConstants.complaintTable)
        .stream(primaryKey: ['complaint_id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .asyncMap((event) async {
          return await getComplaintsByUser(userId);
        });
  }
}
