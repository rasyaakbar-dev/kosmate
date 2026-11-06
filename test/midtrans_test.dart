import 'package:flutter_test/flutter_test.dart';
import 'package:kosmate/models/payment_model.dart';
import 'package:kosmate/services/midtrans_service.dart';

void main() {
  group('Midtrans Core API Models & Parsing', () {
    test('MidtransChargeResponse parses sample response correctly', () {
      final sampleChargeJson = {
        "status_code": "201",
        "status_message": "GO-PAY transaction is created",
        "transaction_id": "231c79c5-e39e-4993-86da-cadcaee56c1d",
        "order_id": "order-101h-1570513296",
        "gross_amount": "44000.00",
        "currency": "IDR",
        "payment_type": "gopay",
        "transaction_time": "2019-10-08 12:41:36",
        "transaction_status": "pending",
        "fraud_status": "accept",
        "actions": [
          {
            "name": "generate-qr-code",
            "method": "GET",
            "url": "https://api.sandbox.veritrans.co.id/v2/gopay/231c79c5/qr-code"
          },
          {
            "name": "deeplink-redirect",
            "method": "GET",
            "url": "https://simulator.sandbox.midtrans.com/gopay/ui/checkout?referenceid=Y0xwjoQ9uy"
          },
          {
            "name": "get-status",
            "method": "GET",
            "url": "https://api.sandbox.veritrans.co.id/v2/231c79c5/status"
          },
          {
            "name": "cancel",
            "method": "POST",
            "url": "https://api.sandbox.veritrans.co.id/v2/231c79c5/cancel"
          }
        ]
      };

      final response = MidtransChargeResponse.fromJson(sampleChargeJson);

      expect(response.statusCode, '201');
      expect(response.orderId, 'order-101h-1570513296');
      expect(response.transactionId, '231c79c5-e39e-4993-86da-cadcaee56c1d');
      expect(response.paymentType, 'gopay');
      expect(response.qrCodeUrl, 'https://api.sandbox.veritrans.co.id/v2/gopay/231c79c5/qr-code');
      expect(response.deeplinkUrl, 'https://simulator.sandbox.midtrans.com/gopay/ui/checkout?referenceid=Y0xwjoQ9uy');
      expect(response.actions.length, 4);
    });

    test('MidtransStatusResponse identifies settlement vs pending vs cancelled', () {
      final settlementJson = {
        "status_code": "200",
        "status_message": "Success, transaction is found",
        "transaction_id": "231c79c5",
        "order_id": "order-101",
        "gross_amount": "44000.00",
        "payment_type": "gopay",
        "transaction_time": "2019-10-08 12:41:36",
        "transaction_status": "settlement",
        "settlement_time": "2019-10-08 12:45:00",
      };

      final status = MidtransStatusResponse.fromJson(settlementJson);
      expect(status.isSettled, isTrue);
      expect(status.isPending, isFalse);
      expect(status.isExpiredOrCancelled, isFalse);

      final pendingJson = {
        "status_code": "201",
        "status_message": "Success",
        "transaction_id": "231c79c5",
        "order_id": "order-101",
        "gross_amount": "44000.00",
        "payment_type": "gopay",
        "transaction_time": "2019-10-08 12:41:36",
        "transaction_status": "pending",
      };

      final pendingStatus = MidtransStatusResponse.fromJson(pendingJson);
      expect(pendingStatus.isSettled, isFalse);
      expect(pendingStatus.isPending, isTrue);
      expect(pendingStatus.isExpiredOrCancelled, isFalse);

      final cancelJson = {
        "status_code": "200",
        "status_message": "Success",
        "transaction_id": "231c79c5",
        "order_id": "order-101",
        "gross_amount": "44000.00",
        "payment_type": "gopay",
        "transaction_time": "2019-10-08 12:41:36",
        "transaction_status": "cancel",
      };

      final cancelStatus = MidtransStatusResponse.fromJson(cancelJson);
      expect(cancelStatus.isExpiredOrCancelled, isTrue);
    });

    test('PaymentModel serializes and deserializes Midtrans fields correctly', () {
      final payment = PaymentModel(
        paymentId: 10,
        userId: 2,
        roomId: 5,
        amount: 1500000,
        dueDate: DateTime(2026, 11, 30),
        status: PaymentStatus.pending,
        orderId: 'KOSMATE-INV-10-12345678',
        transactionId: 'midtrans-tx-999',
        paymentType: 'gopay',
        qrCodeUrl: 'https://api.sandbox.midtrans.com/qr',
        deeplinkUrl: 'https://simulator.sandbox.midtrans.com/pay',
      );

      final json = payment.toJson();
      expect(json['order_id'], 'KOSMATE-INV-10-12345678');
      expect(json['transaction_id'], 'midtrans-tx-999');
      expect(json['payment_type'], 'gopay');
      expect(json['qr_code_url'], 'https://api.sandbox.midtrans.com/qr');
      expect(json['deeplink_url'], 'https://simulator.sandbox.midtrans.com/pay');

      final fromJson = PaymentModel.fromJson({
        'payment_id': 10,
        'user_id': 2,
        'room_id': 5,
        'amount': 1500000,
        'due_date': '2026-11-30',
        'status': 'pending',
        'order_id': 'KOSMATE-INV-10-12345678',
        'transaction_id': 'midtrans-tx-999',
        'payment_type': 'gopay',
        'qr_code_url': 'https://api.sandbox.midtrans.com/qr',
        'deeplink_url': 'https://simulator.sandbox.midtrans.com/pay',
      });

      expect(fromJson.orderId, 'KOSMATE-INV-10-12345678');
      expect(fromJson.transactionId, 'midtrans-tx-999');
      expect(fromJson.paymentType, 'gopay');
      expect(fromJson.qrCodeUrl, 'https://api.sandbox.midtrans.com/qr');
      expect(fromJson.deeplinkUrl, 'https://simulator.sandbox.midtrans.com/pay');
    });
  });
}

