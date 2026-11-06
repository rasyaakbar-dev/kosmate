import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../models/payment_model.dart';
import '../models/user_model.dart';
import 'midtrans_service.dart';

class PaymentService {
  final SupabaseClient _client = supabase;
  final MidtransService _midtransService = MidtransService();

  /// Fetch all payments/invoices for a tenant
  Future<List<PaymentModel>> getPaymentsByUser(int userId) async {
    final response = await _client
        .from(SupabaseConstants.paymentTable)
        .select(
          '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
        )
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
        .select(
          '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey!inner(*, house!room_house_id_fkey!inner(*))',
        )
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
        .select(
          '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
        )
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
        .select(
          '*, users!payment_user_id_fkey(*), room!payment_room_id_fkey(*, house!room_house_id_fkey(*))',
        )
        .single();

    return PaymentModel.fromJson(response);
  }

  /// Owner approves/verifies payment or updates status
  Future<PaymentModel> updatePaymentStatus({
    required int paymentId,
    required PaymentStatus status,
    DateTime? paidDate,
  }) async {
    final updateData = <String, dynamic>{'status': status.name};
    if (paidDate != null) {
      updateData['paid_date'] = paidDate.toIso8601String().split('T').first;
    } else if (status == PaymentStatus.paid) {
      updateData['paid_date'] = DateTime.now()
          .toIso8601String()
          .split('T')
          .first;
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
  }

  /// Initiate a Midtrans GoPay / QRIS transaction for an invoice
  Future<PaymentModel> initiateMidtransPayment({
    required PaymentModel payment,
    required UserModel tenant,
  }) async {
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
  }

  /// Sync and check transaction status directly from Midtrans Core API
  /// If settled, updates status to paid in Supabase automatically.
  Future<PaymentModel> syncPaymentStatusWithMidtrans(
    PaymentModel payment,
  ) async {
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
  }

  /// Cancel an ongoing Midtrans transaction
  Future<PaymentModel> cancelMidtransPayment(PaymentModel payment) async {
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
