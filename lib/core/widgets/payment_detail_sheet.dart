import 'package:flutter/material.dart';

import '../constants/supabase_constants.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../../models/payment_model.dart';
import 'kosmate_components.dart';
import 'private_storage_image.dart';

/// Shared bottom sheet displaying full payment/invoice details, mirroring
/// [TenantComplaintDetailSheet], with optional role-specific actions.
class PaymentDetailSheet extends StatelessWidget {
  final PaymentModel payment;
  final VoidCallback? onPayNow;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onEdit;

  const PaymentDetailSheet({
    super.key,
    required this.payment,
    this.onPayNow,
    this.onMarkPaid,
    this.onEdit,
  });

  static Future<void> show(
    BuildContext context,
    PaymentModel payment, {
    VoidCallback? onPayNow,
    VoidCallback? onMarkPaid,
    VoidCallback? onEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PaymentDetailSheet(
        payment: payment,
        onPayNow: onPayNow,
        onMarkPaid: onMarkPaid,
        onEdit: onEdit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = payment.status == PaymentStatus.paid;
    final isOverdue = payment.status == PaymentStatus.overdue;
    final isCancelled = payment.status == PaymentStatus.cancelled;

    final Color bannerBg;
    final Color bannerFg;
    final IconData bannerIcon;
    if (isPaid) {
      bannerBg = AppTheme.successLight;
      bannerFg = AppTheme.successColor;
      bannerIcon = Icons.check_circle_outline_rounded;
    } else if (isOverdue) {
      bannerBg = AppTheme.destructiveLight;
      bannerFg = AppTheme.destructiveColor;
      bannerIcon = Icons.error_outline_rounded;
    } else if (isCancelled) {
      bannerBg = AppTheme.surfaceLight;
      bannerFg = AppTheme.textMuted;
      bannerIcon = Icons.cancel_outlined;
    } else {
      bannerBg = AppTheme.warningLight;
      bannerFg = AppTheme.warningColor;
      bannerIcon = Icons.receipt_long_outlined;
    }

    final receiptPath = payment.receiptPath;
    final hasReceipt = receiptPath != null && receiptPath.trim().isNotEmpty;
    final periodLabel = Formatters.formatMonthYear(payment.dueDate);
    final roomNumber = payment.room?.roomNumber;
    final houseName = payment.room?.house?.houseName;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Detail',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 16),

            // Status Banner Tile
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bannerBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(bannerIcon, color: bannerFg, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.formatCurrency(payment.amount),
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: bannerFg,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$periodLabel • Invoice #${payment.paymentId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  KosMateStatusChip.fromPaymentStatus(payment.status),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment Information Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment information',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRow('Status', payment.status.displayName),
                  const SizedBox(height: 8),
                  _buildRow(
                    'Amount',
                    Formatters.formatCurrency(payment.amount),
                  ),
                  const SizedBox(height: 8),
                  _buildRow('Due date', Formatters.formatDate(payment.dueDate)),
                  if (payment.paidDate != null) ...[
                    const SizedBox(height: 8),
                    _buildRow(
                      'Paid date',
                      Formatters.formatDate(payment.paidDate),
                    ),
                  ],
                  if (payment.user != null) ...[
                    const SizedBox(height: 8),
                    _buildRow('Tenant', payment.user!.name),
                  ],
                  const SizedBox(height: 8),
                  _buildRow(
                    'Room',
                    roomNumber != null
                        ? (houseName != null
                              ? 'Room $roomNumber • $houseName'
                              : 'Room $roomNumber')
                        : 'Room #${payment.roomId}',
                  ),
                  if (payment.paymentType != null &&
                      payment.paymentType!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildRow('Method', payment.paymentType!),
                  ],
                  if (payment.orderId != null &&
                      payment.orderId!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildRow('Order ID', payment.orderId!),
                  ],
                ],
              ),
            ),

            if (hasReceipt) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment receipt',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PrivateStorageImage(
                      bucketName: SupabaseConstants.paymentReceiptsBucket,
                      path: receiptPath,
                      height: 200,
                    ),
                  ],
                ),
              ),
            ],

            if (onPayNow != null || onMarkPaid != null || onEdit != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onPayNow != null && !isPaid && !isCancelled)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onPayNow!();
                        },
                        icon: const Icon(Icons.payment_rounded, size: 18),
                        label: const Text('Pay Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  if (onMarkPaid != null && !isPaid && !isCancelled) ...[
                    if (onPayNow != null) const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onMarkPaid!();
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Mark as Paid'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (onEdit != null) ...[
                    if ((onPayNow != null || onMarkPaid != null) &&
                        !isPaid &&
                        !isCancelled)
                      const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onEdit!();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Invoice'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.foregroundColor,
            ),
          ),
        ),
      ],
    );
  }
}
