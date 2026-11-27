import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/formatters.dart';
import '../core/utils/json_helpers.dart';
import '../models/complaint_model.dart';

class ComplaintService {
  final SupabaseClient _client;

  static const String _selectWithRelations =
      '*, users!complaint_user_id_fkey(*), room!complaint_room_id_fkey(*, house!room_house_id_fkey(*))';

  ComplaintService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  Future<ComplaintModel> createComplaint({
    required int userId,
    required int roomId,
    required ComplaintCategory category,
    required String title,
    required String description,
    required ComplaintPriority priority,
    String? attachmentPath,
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
            'attachment_url': attachmentPath,
          })
          .select(_selectWithRelations)
          .single();

      return ComplaintModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to submit complaint.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to submit complaint.', cause: e);
    }
  }

  Future<List<ComplaintModel>> getComplaintsByUser(int userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.complaintTable)
          .select(_selectWithRelations)
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).mapToModel(ComplaintModel.fromJson);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load user complaints.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load user complaints.', cause: e);
    }
  }

  Future<List<ComplaintModel>> getComplaintsByRoom(int roomId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.complaintTable)
          .select(_selectWithRelations)
          .eq('room_id', roomId)
          .order('created_at', ascending: false);

      return (response as List).mapToModel(ComplaintModel.fromJson);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load room complaints.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load room complaints.', cause: e);
    }
  }

  Future<ComplaintModel?> getLatestComplaintForRoom(int roomId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.complaintTable)
          .select('*, users!complaint_user_id_fkey(*)')
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return ComplaintModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load latest room complaint.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load latest room complaint.', cause: e);
    }
  }

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
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load owner complaints.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load owner complaints.', cause: e);
    }
  }

  Future<List<ComplaintModel>> getAllComplaints() async {
    try {
      final response = await _client
          .from(SupabaseConstants.complaintTable)
          .select(_selectWithRelations)
          .order('created_at', ascending: false);

      return (response as List).mapToModel(ComplaintModel.fromJson);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load complaints.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load complaints.', cause: e);
    }
  }

  Future<ComplaintModel> updateComplaintStatus({
    required int complaintId,
    required ComplaintStatus status,
    String? responseText,
  }) {
    final trimmed = responseText?.trim();
    return _updateComplaint(
      complaintId: complaintId,
      status: status,
      responseText: (trimmed != null && trimmed.isNotEmpty) ? trimmed : null,
      errorMessage: 'Failed to update complaint status.',
    );
  }

  Future<ComplaintModel> respondToComplaint({
    required int complaintId,
    required String responseText,
    required ComplaintStatus status,
  }) {
    return _updateComplaint(
      complaintId: complaintId,
      status: status,
      responseText: responseText.trim(),
      errorMessage: 'Failed to respond to complaint.',
    );
  }

  Future<ComplaintModel> _updateComplaint({
    required int complaintId,
    required ComplaintStatus status,
    required String? responseText,
    required String errorMessage,
  }) async {
    try {
      final updateData = <String, dynamic>{'status': status.dbValue};
      if (responseText != null) {
        updateData['response'] = responseText;
      }

      final response = await _client
          .from(SupabaseConstants.complaintTable)
          .update(updateData)
          .eq('complaint_id', complaintId)
          .select(_selectWithRelations)
          .single();

      return ComplaintModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException(errorMessage, code: e.code, cause: e);
    } catch (e) {
      throw ServiceException(errorMessage, cause: e);
    }
  }

  Stream<List<ComplaintModel>> streamComplaintsByUser(int userId) {
    return _client
        .from(SupabaseConstants.complaintTable)
        .stream(primaryKey: ['complaint_id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .asyncMap((_) => getComplaintsByUser(userId));
  }
}
