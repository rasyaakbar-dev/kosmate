class MidtransAction {
  final String name;
  final String method;
  final String url;

  const MidtransAction({
    required this.name,
    required this.method,
    required this.url,
  });

  factory MidtransAction.fromJson(Map<String, dynamic> json) {
    return MidtransAction(
      name: json['name'] as String? ?? '',
      method: json['method'] as String? ?? 'GET',
      url: json['url'] as String? ?? '',
    );
  }
}

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

  const MidtransChargeResponse({
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

  String? get qrCodeUrl => _actionUrl('generate-qr-code');

  String? get deeplinkUrl => _actionUrl('deeplink-redirect');

  String? _actionUrl(String name) {
    for (final action in actions) {
      if (action.name == name) return action.url;
    }
    return null;
  }

  factory MidtransChargeResponse.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    final actions = rawActions is List
        ? rawActions
              .whereType<Map<String, dynamic>>()
              .map(MidtransAction.fromJson)
              .toList()
        : <MidtransAction>[];

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
      actions: actions,
    );
  }
}

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

  const MidtransStatusResponse({
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
