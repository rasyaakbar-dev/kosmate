import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/payment_model.dart';
import '../../../models/user_model.dart';
import '../widgets/midtrans_payment_sheet.dart';

class TenantPaymentsTab extends StatefulWidget {
  final UserModel user;
  const TenantPaymentsTab({super.key, required this.user});

  @override
  State<TenantPaymentsTab> createState() => _TenantPaymentsTabState();
}

class _TenantPaymentsTabState extends State<TenantPaymentsTab> {
  final _paymentService = sl.payment;
  late Future<List<PaymentModel>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() {
    setState(() {
      _paymentsFuture = _paymentService.getPaymentsByUser(widget.user.userId);
    });
  }

  void _startMidtransPayment(PaymentModel payment) async {
    if (payment.qrCodeUrl != null && payment.orderId != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MidtransPaymentSheet(
          payment: payment,
          onPaymentSuccess: _loadPayments,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to Midtrans Core API...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final chargedPayment = await _paymentService.initiateMidtransPayment(
        payment: payment,
        tenant: widget.user,
      );
      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MidtransPaymentSheet(
          payment: chargedPayment,
          onPaymentSuccess: _loadPayments,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to initialize GoPay/QRIS: $e')),
      );
    }
  }

  void _showSubmitReceiptDialog(PaymentModel payment) {
    final receiptController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Payment Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${Formatters.formatCurrency(payment.amount)}'),
            const SizedBox(height: 12),
            TextField(
              controller: receiptController,
              decoration: const InputDecoration(
                labelText: 'Receipt / Transfer Reference URL',
                hintText: 'https://...',
              ),
            ),
          ],
        ),
        actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (receiptController.text.trim().isEmpty) return;
            try {
              await _paymentService.submitReceipt(
                paymentId: payment.paymentId,
                receiptUrl: receiptController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadPayments();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Receipt submitted successfully!'),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          },
          child: const Text('Submit'),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _loadPayments(),
      child: FutureBuilder<List<PaymentModel>>(
        future: _paymentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final payments = snapshot.data ?? [];
          if (payments.isEmpty) {
            return const KosMateEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No invoices yet',
              subtitle: 'Your payment history will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final p = payments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            Formatters.formatCurrency(p.amount),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          KosMateStatusChip.fromPaymentStatus(p.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Due Date: ${Formatters.formatDate(p.dueDate)}'),
                      if (p.paidDate != null)
                        Text('Paid On: ${Formatters.formatDate(p.paidDate)}'),
                      if (p.orderId != null &&
                          p.status == PaymentStatus.pending) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Order ID: ${p.orderId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                      if (p.status == PaymentStatus.pending) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  p.qrCodeUrl != null
                                      ? 'Continue GoPay / QRIS'
                                      : 'Pay with GoPay / QRIS',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () => _startMidtransPayment(p),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.upload_file, size: 16),
                            label: const Text(
                              'Or submit manual receipt',
                              style: TextStyle(fontSize: 13),
                            ),
                            onPressed: () => _showSubmitReceiptDialog(p),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
