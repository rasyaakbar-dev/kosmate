import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/supabase_constants.dart';
import '../models/user_model.dart';

/// Models an action returned in the Midtrans Charge response
class MidtransAction {
  final String name;
  final String method;
  final String url;

  MidtransAction({required this.name, required this.method, required this.url});

  factory MidtransAction.fromJson(Map<String, dynamic> json) {
    return MidtransAction(
      name: json['name'] as String? ?? '',
      method: json['method'] as String? ?? 'GET',
      url: json['url'] as String? ?? '',
    );
  }
}

/// Response returned from Midtrans /v2/charge endpoint
class MidtransChargeResponse {
  final String statusCode;
  final String statusMessage;
  final String transactionId;
  final String orderId;
  final String grossAmount;
  final String currency;
  final String paymentType;
  final String transactionTime;
  final String transactionStatus;
  final List<MidtransAction> actions;

  MidtransChargeResponse({
    required this.statusCode,
    required this.statusMessage,
    required this.transactionId,
    required this.orderId,
    required this.grossAmount,
    required this.currency,
    required this.paymentType,
    required this.transactionTime,
    required this.transactionStatus,
    required this.actions,
  });

  String? get qrCodeUrl {
    for (final action in actions) {
      if (action.name == 'generate-qr-code') {
        return action.url;
      }
    }
    return null;
  }

  String? get deeplinkUrl {
    for (final action in actions) {
      if (action.name == 'deeplink-redirect') {
        return action.url;
      }
    }
    return null;
  }

  factory MidtransChargeResponse.fromJson(Map<String, dynamic> json) {
    final actionsList =
        (json['actions'] as List?)
            ?.map((e) => MidtransAction.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return MidtransChargeResponse(
      statusCode: json['status_code']?.toString() ?? '',
      statusMessage: json['status_message']?.toString() ?? '',
      transactionId: json['transaction_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      grossAmount: json['gross_amount']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'IDR',
      paymentType: json['payment_type']?.toString() ?? 'gopay',
      transactionTime: json['transaction_time']?.toString() ?? '',
      transactionStatus: json['transaction_status']?.toString() ?? 'pending',
      actions: actionsList,
    );
  }
}

/// Response from Midtrans /v2/{order_id}/status endpoint
class MidtransStatusResponse {
  final String statusCode;
  final String statusMessage;
  final String transactionId;
  final String orderId;
  final String grossAmount;
  final String paymentType;
  final String transactionTime;
  final String transactionStatus;
  final String? settlementTime;

  MidtransStatusResponse({
    required this.statusCode,
    required this.statusMessage,
    required this.transactionId,
    required this.orderId,
    required this.grossAmount,
    required this.paymentType,
    required this.transactionTime,
    required this.transactionStatus,
    this.settlementTime,
  });

  bool get isSettled =>
      transactionStatus == 'settlement' || transactionStatus == 'capture';

  bool get isPending => transactionStatus == 'pending';

  bool get isExpiredOrCancelled =>
      transactionStatus == 'expire' ||
      transactionStatus == 'cancel' ||
      transactionStatus == 'deny';

  factory MidtransStatusResponse.fromJson(Map<String, dynamic> json) {
    return MidtransStatusResponse(
      statusCode: json['status_code']?.toString() ?? '',
      statusMessage: json['status_message']?.toString() ?? '',
      transactionId: json['transaction_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      grossAmount: json['gross_amount']?.toString() ?? '',
      paymentType: json['payment_type']?.toString() ?? '',
      transactionTime: json['transaction_time']?.toString() ?? '',
      transactionStatus: json['transaction_status']?.toString() ?? '',
      settlementTime: json['settlement_time']?.toString(),
    );
  }
}

class MidtransService {
  final http.Client _client = http.Client();

  String get _authHeader {
    final key = MidtransConstants.serverKey;
    final bytes = utf8.encode('$key:');
    return 'Basic ${base64Encode(bytes)}';
  }

  /// Charge GoPay / QRIS transaction via Midtrans Core API /v2/charge
  Future<MidtransChargeResponse> chargeEWallet({
    required String orderId,
    required double grossAmount,
    required UserModel customer,
    String? callbackUrl,
  }) async {
    final url = Uri.parse('${MidtransConstants.baseUrl}/charge');

    final payload = <String, dynamic>{
      'payment_type': 'gopay',
      'transaction_details': {
        'order_id': orderId,
        'gross_amount': grossAmount.round(),
      },
      'customer_details': {
        'first_name': customer.name,
        'email': customer.email,
        'phone': customer.phone,
      },
      'gopay': {
        'enable_callback': true,
        'callback_url': callbackUrl ?? 'kosmate://payment-finish',
      },
    };

    final response = await _client.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': _authHeader,
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MidtransChargeResponse.fromJson(json);
    } else {
      Map<String, dynamic>? errorJson;
      try {
        errorJson = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {}

      final message =
          errorJson?['status_message'] ??
          'Midtrans request failed with status code ${response.statusCode}';
      throw Exception(message);
    }
  }

  /// Check transaction status via Midtrans Core API /v2/{order_id}/status
  Future<MidtransStatusResponse> getTransactionStatus(String orderId) async {
    final url = Uri.parse('${MidtransConstants.baseUrl}/$orderId/status');

    final response = await _client.get(
      url,
      headers: {'Accept': 'application/json', 'Authorization': _authHeader},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return MidtransStatusResponse.fromJson(json);
    } else {
      Map<String, dynamic>? errorJson;
      try {
        errorJson = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {}

      final message =
          errorJson?['status_message'] ??
          'Failed to check Midtrans status (${response.statusCode})';
      throw Exception(message);
    }
  }

  /// Cancel an unpaid transaction via Midtrans Core API /v2/{order_id}/cancel
  Future<bool> cancelTransaction(String orderId) async {
    try {
      final url = Uri.parse('${MidtransConstants.baseUrl}/$orderId/cancel');

      final response = await _client.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': _authHeader,
        },
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
