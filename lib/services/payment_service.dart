import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../models/payment_model.dart';

class PaymentService {
  final SupabaseClient _client = supabase;

  /// Fetch all payments/invoices for a tenant
  Future<List<PaymentModel>> getPaymentsByUser(int userId) async {
    final response = await _client
        .from(SupabaseConstants.paymentTable)
        .select('*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))')
        .eq('user_id', userId)
        .order('due_date', ascending: false);

    return (response as List)
        .map((json) => PaymentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Fetch all payments for rooms owned by a specific owner
  Future<List<PaymentModel>> getPaymentsForOwner(int ownerId) async {
    final response = await _client
        .from(SupabaseConstants.paymentTable)
        .select('*, users!payment_user_id_fkey(*), room!payment_room_id_fkey!inner(*, house!room_house_id_fkey!inner(*))')
        .eq('room.house.owner_id', ownerId)
        .order('due_date', ascending: false);

    return (response as List)
        .map((json) => PaymentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Create an invoice/bill for a tenant
  Future<PaymentModel> createPayment({
    required int userId,
    required int roomId,
    required double amount,
    required DateTime dueDate,
  }) async {
    final response = await _client
        .from(SupabaseConstants.paymentTable)
        .insert({
          'user_id': userId,
          'room_id': roomId,
          'amount': amount,
          'due_date': dueDate.toIso8601String().split('T').first,
          'status': PaymentStatus.pending.name,
        })
        .select('*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))')
        .single();

    return PaymentModel.fromJson(response);
  }

  /// Tenant submits payment proof receipt
  Future<PaymentModel> submitReceipt({
    required int paymentId,
    required String receiptUrl,
  }) async {
    final response = await _client
        .from(SupabaseConstants.paymentTable)
        .update({
          'receipt_url': receiptUrl,
          'paid_date': DateTime.now().toIso8601String().split('T').first,
          // Remains pending until owner verifies or set to paid
        })
        .eq('payment_id', paymentId)
        .select('*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))')
        .single();

    return PaymentModel.fromJson(response);
  }

  /// Owner approves/verifies payment or updates status
  Future<PaymentModel> updatePaymentStatus({
    required int paymentId,
    required PaymentStatus status,
    DateTime? paidDate,
  }) async {
    final updateData = <String, dynamic>{
      'status': status.name,
    };
    if (paidDate != null) {
      updateData['paid_date'] = paidDate.toIso8601String().split('T').first;
    } else if (status == PaymentStatus.paid) {
      updateData['paid_date'] = DateTime.now().toIso8601String().split('T').first;
    }

    final response = await _client
        .from(SupabaseConstants.paymentTable)
        .update(updateData)
        .eq('payment_id', paymentId)
        .select('*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))')
        .single();

    return PaymentModel.fromJson(response);
  }

  /// Realtime stream of payments for a user
  Stream<List<PaymentModel>> streamPaymentsByUser(int userId) {
    return _client
        .from(SupabaseConstants.paymentTable)
        .stream(primaryKey: ['payment_id'])
        .eq('user_id', userId)
        .order('due_date', ascending: false)
        .asyncMap((event) async {
          return await getPaymentsByUser(userId);
        });
  }
}

