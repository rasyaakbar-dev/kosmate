import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/app_exception.dart';

class MidtransService {
  final SupabaseClient _client;

  MidtransService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  Future<void> chargePayment(int paymentId) => _invoke('charge', paymentId);

  Future<void> refreshPaymentStatus(int paymentId) =>
      _invoke('status', paymentId);

  Future<void> cancelPayment(int paymentId) => _invoke('cancel', paymentId);

  Future<void> _invoke(String action, int paymentId) async {
    try {
      final response = await _client.functions.invoke(
        'midtrans-payment',
        body: {'action': action, 'paymentId': paymentId},
      );

      if (response.status < 200 || response.status >= 300) {
        final responseBody = response.data;
        final message = responseBody is Map
            ? responseBody['error']?.toString()
            : null;
        throw ServiceException(
          message ?? 'Payment operation failed (${response.status}).',
          code: response.status.toString(),
        );
      }
    } on AppException {
      rethrow;
    } catch (error) {
      throw ServiceException(
        'Unable to complete the payment operation.',
        cause: error,
      );
    }
  }
}
