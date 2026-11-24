import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/formatters.dart';
import '../core/utils/supabase_helpers.dart';
import '../models/payment_model.dart';
import '../models/user_model.dart';
import 'midtrans_service.dart';

class PaymentService {
  final SupabaseClient _client = supabase;
  final MidtransService _midtransService;

  PaymentService([MidtransService? midtransService])
    : _midtransService = midtransService ?? MidtransService();

  /// Fetch all payments/invoices for a tenant
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

  /// Fetch all payments for rooms owned by a specific owner
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

  /// Fetch all payments platform-wide (Admin)
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

  /// Full update payment for Admin
  Future<PaymentModel> updatePayment({
    required int paymentId,
    required int userId,
    required int roomId,
    required double amount,
    required DateTime dueDate,
    required PaymentStatus status,
    DateTime? paidDate,
    String? receiptUrl,
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
      if (receiptUrl != null) {
        updateData['receipt_url'] = receiptUrl;
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

  /// Delete a payment (Admin)
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

  /// Create an invoice/bill for a tenant
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

  /// Tenant submits payment proof receipt
  Future<PaymentModel> submitReceipt({
    required int paymentId,
    required String receiptUrl,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.paymentTable)
          .update({
            'receipt_url': receiptUrl,
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

  /// Owner approves/verifies payment or updates status
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

  /// Initiate a Midtrans GoPay / QRIS transaction for an invoice
  Future<PaymentModel> initiateMidtransPayment({
    required PaymentModel payment,
    required UserModel tenant,
  }) async {
    try {
      // If an order has already been charged and QR code exists, return the existing payment
      if (payment.orderId != null && payment.qrCodeUrl != null) {
        return payment;
      }

      final orderId =
          'KOSMATE-INV-${payment.paymentId}-${DateTime.now().millisecondsSinceEpoch}';
      final chargeRes = await _midtransService.chargeEWallet(
        orderId: orderId,
        grossAmount: payment.amount,
        customer: tenant,
      );

      final updateData = <String, dynamic>{
        'order_id': orderId,
        'transaction_id': chargeRes.transactionId,
        'payment_type': chargeRes.paymentType,
        'qr_code_url': chargeRes.qrCodeUrl,
        'deeplink_url': chargeRes.deeplinkUrl,
      };

      final response = await _client
          .from(SupabaseConstants.paymentTable)
          .update(updateData)
          .eq('payment_id', payment.paymentId)
          .select(
            '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .single();

      return PaymentModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServiceException(
        'Failed to initiate Midtrans transaction.',
        cause: e,
      );
    }
  }

  /// Sync and check transaction status directly from Midtrans Core API
  /// If settled, updates status to paid in Supabase automatically.
  Future<PaymentModel> syncPaymentStatusWithMidtrans(
    PaymentModel payment,
  ) async {
    try {
      if (payment.orderId == null) {
        return payment;
      }

      final statusRes = await _midtransService.getTransactionStatus(
        payment.orderId!,
      );

      if (statusRes.isSettled) {
        return await updatePaymentStatus(
          paymentId: payment.paymentId,
          status: PaymentStatus.paid,
          paidDate: DateTime.now(),
        );
      } else if (statusRes.isExpiredOrCancelled) {
        // Clear Midtrans order metadata so tenant can generate a fresh payment
        final response = await _client
            .from(SupabaseConstants.paymentTable)
            .update({
              'order_id': null,
              'transaction_id': null,
              'qr_code_url': null,
              'deeplink_url': null,
            })
            .eq('payment_id', payment.paymentId)
            .select(
              '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
            )
            .single();

        return PaymentModel.fromJson(response);
      }

      return payment;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServiceException(
        'Failed to sync payment status with Midtrans.',
        cause: e,
      );
    }
  }

  /// Cancel an ongoing Midtrans transaction
  Future<PaymentModel> cancelMidtransPayment(PaymentModel payment) async {
    try {
      if (payment.orderId != null) {
        await _midtransService.cancelTransaction(payment.orderId!);
      }

      final response = await _client
          .from(SupabaseConstants.paymentTable)
          .update({
            'order_id': null,
            'transaction_id': null,
            'qr_code_url': null,
            'deeplink_url': null,
          })
          .eq('payment_id', payment.paymentId)
          .select(
            '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
          )
          .single();

      return PaymentModel.fromJson(response);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServiceException('Failed to cancel Midtrans payment.', cause: e);
    }
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
