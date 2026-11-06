import 'user_model.dart';
import 'room_model.dart';

enum PaymentStatus {
  pending,
  paid,
  overdue,
  cancelled;

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PaymentStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.overdue:
        return 'Overdue';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class PaymentModel {
  final int paymentId;
  final int userId;
  final int roomId;
  final double amount;
  final DateTime dueDate;
  final PaymentStatus status;
  final DateTime? paidDate;
  final String? receiptUrl;
  final String? orderId;
  final String? transactionId;
  final String? paymentType;
  final String? qrCodeUrl;
  final String? deeplinkUrl;
  final DateTime? createdAt;
  final UserModel? user;
  final RoomModel? room;

  PaymentModel({
    required this.paymentId,
    required this.userId,
    required this.roomId,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.paidDate,
    this.receiptUrl,
    this.orderId,
    this.transactionId,
    this.paymentType,
    this.qrCodeUrl,
    this.deeplinkUrl,
    this.createdAt,
    this.user,
    this.room,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      paymentId: json['payment_id'] is int
          ? json['payment_id'] as int
          : int.parse(json['payment_id'].toString()),
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.parse(json['user_id'].toString()),
      roomId: json['room_id'] is int
          ? json['room_id'] as int
          : int.parse(json['room_id'].toString()),
      amount: json['amount'] != null
          ? double.tryParse(json['amount'].toString()) ?? 0.0
          : 0.0,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: PaymentStatus.fromString(json['status'] as String? ?? 'pending'),
      paidDate: json['paid_date'] != null
          ? DateTime.tryParse(json['paid_date'].toString())
          : null,
      receiptUrl: json['receipt_url'] as String?,
      orderId: json['order_id'] as String?,
      transactionId: json['transaction_id'] as String?,
      paymentType: json['payment_type'] as String?,
      qrCodeUrl: json['qr_code_url'] as String?,
      deeplinkUrl: json['deeplink_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      user: json['users'] != null && json['users'] is Map<String, dynamic>
          ? UserModel.fromJson(json['users'] as Map<String, dynamic>)
          : null,
      room: json['room'] != null && json['room'] is Map<String, dynamic>
          ? RoomModel.fromJson(json['room'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'user_id': userId,
      'room_id': roomId,
      'amount': amount,
      'due_date': dueDate.toIso8601String().split('T').first,
      'status': status.name,
      'paid_date': paidDate?.toIso8601String().split('T').first,
      'receipt_url': receiptUrl,
      'order_id': orderId,
      'transaction_id': transactionId,
      'payment_type': paymentType,
      'qr_code_url': qrCodeUrl,
      'deeplink_url': deeplinkUrl,
    };
    if (includeId) {
      map['payment_id'] = paymentId;
    }
    return map;
  }

  PaymentModel copyWith({
    int? paymentId,
    int? userId,
    int? roomId,
    double? amount,
    DateTime? dueDate,
    PaymentStatus? status,
    DateTime? paidDate,
    String? receiptUrl,
    String? orderId,
    String? transactionId,
    String? paymentType,
    String? qrCodeUrl,
    String? deeplinkUrl,
    DateTime? createdAt,
    UserModel? user,
    RoomModel? room,
  }) {
    return PaymentModel(
      paymentId: paymentId ?? this.paymentId,
      userId: userId ?? this.userId,
      roomId: roomId ?? this.roomId,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      paidDate: paidDate ?? this.paidDate,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      orderId: orderId ?? this.orderId,
      transactionId: transactionId ?? this.transactionId,
      paymentType: paymentType ?? this.paymentType,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      deeplinkUrl: deeplinkUrl ?? this.deeplinkUrl,
      createdAt: createdAt ?? this.createdAt,
      user: user ?? this.user,
      room: room ?? this.room,
    );
  }
}
