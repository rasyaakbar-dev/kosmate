import 'package:flutter/material.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/complaint_response_sheet.dart';
import '../../../../core/widgets/list_controls.dart';
import '../../../../core/widgets/payment_detail_sheet.dart';
import '../../../../core/widgets/private_storage_image.dart';
import '../../../../models/booking_model.dart';
import '../../../../models/complaint_model.dart';
import '../../../../models/payment_model.dart';

class TenantInspectorSheet extends StatefulWidget {
  final BookingModel booking;
  final List<ComplaintModel> complaints;
  final List<PaymentModel> payments;
  final VoidCallback onDataChanged;
  final VoidCallback? onIssueInvoice;

  const TenantInspectorSheet({
    super.key,
    required this.booking,
    required this.complaints,
    required this.payments,
    required this.onDataChanged,
    this.onIssueInvoice,
  });

  @override
  State<TenantInspectorSheet> createState() => TenantInspectorSheetState();
}

class TenantInspectorSheetState extends State<TenantInspectorSheet> {
  final _paymentService = sl.payment;

  void _showComplaintResponseDialog(ComplaintModel complaint) {
    ComplaintResponseSheet.show(
      context,
      complaint,
      onUpdated: widget.onDataChanged,
    );
  }

  void _markPaymentPaid(PaymentModel payment) async {
    final receiptPath = payment.receiptPath;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (receiptPath != null && receiptPath.isNotEmpty) ...[
              PrivateStorageImage(
                bucketName: SupabaseConstants.paymentReceiptsBucket,
                path: receiptPath,
                height: 180,
              ),
              const SizedBox(height: 12),
            ] else
              const Text('No receipt has been uploaded.'),
            Text(
              'Mark invoice of ${Formatters.formatCurrency(payment.amount)} as paid?',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm as Paid'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _paymentService.updatePaymentStatus(
          paymentId: payment.paymentId,
          status: PaymentStatus.paid,
        );
        widget.onDataChanged();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.booking.user;
    final room = widget.booking.room;
    final house = room?.house;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primaryLight,
                          child: Text(
                            tenant?.name.isNotEmpty == true
                                ? tenant!.name[0].toUpperCase()
                                : 'T',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tenant?.name ?? 'Tenant Details',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.foregroundColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tenant?.email ?? 'No email',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tenant?.phone ?? 'No phone',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Occupied Room',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  room?.roomNumber ??
                                      'Room ${widget.booking.roomId}',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.foregroundColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${Formatters.formatCurrency(room?.price ?? 0)} / mo',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${house?.houseName ?? "Boarding House"} • ${room?.roomType ?? "Standard"}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Move-in Date: ${Formatters.formatDate(widget.booking.requestDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Complaints',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.foregroundColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.complaints.length} filed',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.complaints.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No complaints reported by this tenant.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      )
                    else
                      ...widget.complaints.map((c) {
                        final isResolved = c.status == ComplaintStatus.resolved;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isResolved
                                    ? Icons.task_alt_outlined
                                    : Icons.build_circle_outlined,
                                color: isResolved
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.title,
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.foregroundColor,
                                      ),
                                    ),
                                    Text(
                                      c.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () =>
                                    _showComplaintResponseDialog(c),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  side: const BorderSide(
                                    color: AppTheme.borderMedium,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  isResolved ? 'View' : 'Respond',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Payment History',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.foregroundColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onIssueInvoice != null) ...[
                              KosMateHeaderActionButton(
                                icon: Icons.add,
                                label: 'Issue Invoice',
                                onPressed: widget.onIssueInvoice!,
                                collapseBreakpoint: 450,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              '${widget.payments.length} invoices',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.payments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No payment invoices recorded yet.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      )
                    else
                      ...widget.payments.map((p) {
                        final isPaid = p.status == PaymentStatus.paid;
                        return InkWell(
                          onTap: () => PaymentDetailSheet.show(
                            context,
                            p,
                            onMarkPaid: !isPaid
                                ? () => _markPaymentPaid(p)
                                : null,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isPaid
                                      ? Icons.check_circle_outline
                                      : Icons.receipt_long_outlined,
                                  color: isPaid
                                      ? AppTheme.successColor
                                      : AppTheme.destructiveColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        Formatters.formatCurrency(p.amount),
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.foregroundColor,
                                        ),
                                      ),
                                      Text(
                                        'Due: ${Formatters.formatDate(p.dueDate)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isPaid)
                                  ElevatedButton(
                                    onPressed: () => _markPaymentPaid(p),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentColor,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                    ),
                                    child: const Text(
                                      'Mark Paid',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Paid',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.successColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
