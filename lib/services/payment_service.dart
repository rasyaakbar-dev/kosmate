import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/formatters.dart';
import '../core/utils/supabase_helpers.dart';
import '../models/payment_model.dart';
import 'midtrans_service.dart';

class PaymentService {
  final SupabaseClient _client = supabase;
  final MidtransService _midtransService;

  PaymentService([MidtransService? midtransService])
    : _midtransService = midtransService ?? MidtransService();

  Future<List<PaymentModel>> getPaymentsByUser(int userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.paymentTable)
          .select(
            '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .eq('user_id', userId)
          .order('due_date', ascending: false);

      return (response as List).mapToModel(PaymentModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load user payments.', cause: e);
    }
  }

  Future<List<PaymentModel>> getPaymentsForOwner(int ownerId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.paymentTable)
          .select(
            '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey!inner(*, house!room_house_id_fkey!inner(*))',
          )
          .eq('room.house.owner_id', ownerId)
          .order('due_date', ascending: false);

      return (response as List).mapToModel(PaymentModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load payments for owner.', cause: e);
    }
  }

  Future<List<PaymentModel>> getAllPayments() async {
    try {
      final response = await _client
          .from(SupabaseConstants.paymentTable)
          .select(
            '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .order('due_date', ascending: false);

      return (response as List).mapToModel(PaymentModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load all payments.', cause: e);
    }
  }

  Future<PaymentModel> updatePayment({
    required int paymentId,
    required int userId,
    required int roomId,
    required double amount,
    required DateTime dueDate,
    required PaymentStatus status,
    DateTime? paidDate,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'user_id': userId,
        'room_id': roomId,
        'amount': amount,
        'due_date': Formatters.toDateString(dueDate),
        'status': status.name,
      };
      if (paidDate != null) {
        updateData['paid_date'] = Formatters.toDateString(paidDate);
      }
      final response = await _client
          .from(SupabaseConstants.paymentTable)
          .update(updateData)
          .eq('payment_id', paymentId)
          .select(
            '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .single();

      return PaymentModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to update payment.', cause: e);
    }
  }

  Future<void> deletePayment(int paymentId) async {
    try {
      await _client
          .from(SupabaseConstants.paymentTable)
          .delete()
          .eq('payment_id', paymentId);
    } catch (e) {
      throw ServiceException('Failed to delete payment.', cause: e);
    }
  }

  Future<PaymentModel> createPayment({
    required int userId,
    required int roomId,
    required double amount,
    required DateTime dueDate,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.paymentTable)
          .insert({
            'user_id': userId,
            'room_id': roomId,
            'amount': amount,
            'due_date': Formatters.toDateString(dueDate),
            'status': PaymentStatus.pending.name,
          })
          .select(
            '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .single();

      return PaymentModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to create payment invoice.', cause: e);
    }
  }

  Future<PaymentModel> submitReceipt({
    required int paymentId,
    required String receiptPath,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.paymentTable)
          .update({
            'receipt_url': receiptPath,
            // Status remains pending until owner verifies or Midtrans confirms.
            // paid_date is set only when status transitions to paid.
          })
          .eq('payment_id', paymentId)
          .select(
            '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .single();

      return PaymentModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to submit receipt proof.', cause: e);
    }
  }

  Future<PaymentModel> updatePaymentStatus({
    required int paymentId,
    required PaymentStatus status,
    DateTime? paidDate,
  }) async {
    try {
      final updateData = <String, dynamic>{'status': status.name};
      if (paidDate != null) {
        updateData['paid_date'] = Formatters.toDateString(paidDate);
      } else if (status == PaymentStatus.paid) {
        updateData['paid_date'] = Formatters.toDateString(DateTime.now());
      }

      final response = await _client
          .from(SupabaseConstants.paymentTable)
          .update(updateData)
          .eq('payment_id', paymentId)
          .select(
            '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .single();

      return PaymentModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to update payment status.', cause: e);
    }
  }

  Future<PaymentModel> initiateMidtransPayment({
    required PaymentModel payment,
  }) async {
    try {
      if (payment.orderId != null && payment.qrCodeUrl != null) {
        return payment;
      }

      await _midtransService.chargePayment(payment.paymentId);
      return await _getPaymentById(payment.paymentId);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServiceException(
        'Failed to initiate Midtrans transaction.',
        cause: e,
      );
    }
  }

  Future<PaymentModel> syncPaymentStatusWithMidtrans(
    PaymentModel payment,
  ) async {
    try {
      if (payment.orderId == null) {
        return payment;
      }

      await _midtransService.refreshPaymentStatus(payment.paymentId);
      return await _getPaymentById(payment.paymentId);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServiceException(
        'Failed to sync payment status with Midtrans.',
        cause: e,
      );
    }
  }

  Future<PaymentModel> cancelMidtransPayment(PaymentModel payment) async {
    try {
      if (payment.orderId != null) {
        await _midtransService.cancelPayment(payment.paymentId);
      }

      return await _getPaymentById(payment.paymentId);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServiceException('Failed to cancel Midtrans payment.', cause: e);
    }
  }

  Future<PaymentModel> _getPaymentById(int paymentId) async {
    final response = await _client
        .from(SupabaseConstants.paymentTable)
        .select(
          '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
        )
        .eq('payment_id', paymentId)
        .single();
    return PaymentModel.fromJson(response);
  }

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
