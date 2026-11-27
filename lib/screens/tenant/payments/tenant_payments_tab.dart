import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../core/widgets/list_controls.dart';
import '../../../core/widgets/payment_detail_sheet.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/user_model.dart';
import '../widgets/midtrans_payment_sheet.dart';
import 'widgets/qris_payment_card.dart';
import 'widgets/submit_receipt_dialog.dart';

class TenantPaymentsTab extends StatefulWidget {
  final UserModel user;
  const TenantPaymentsTab({super.key, required this.user});

  @override
  State<TenantPaymentsTab> createState() => _TenantPaymentsTabState();
}

class _TenantPaymentsTabState extends State<TenantPaymentsTab> {
  final _paymentService = sl.payment;
  final _bookingService = sl.booking;
  final _historySearchController = TextEditingController();

  bool _isLoading = true;
  List<PaymentModel> _payments = [];
  BookingModel? _activeBooking;
  String _historySearchQuery = '';
  String _historyStatusFilter = 'All';
  String _historySortId = 'due_desc';
  int _historyPage = 1;
  int _historyPageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _historySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final payments = await _paymentService.getPaymentsByUser(
        widget.user.userId,
      );
      final bookings = await _bookingService.getBookingsByUser(
        widget.user.userId,
      );
      final active = bookings
          .where((b) => b.status == BookingStatus.approved)
          .firstOrNull;

      if (mounted) {
        setState(() {
          _payments = payments;
          _activeBooking = active;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startMidtransPayment(PaymentModel payment) async {
    if (payment.qrCodeUrl != null && payment.orderId != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            MidtransPaymentSheet(payment: payment, onPaymentSuccess: _loadData),
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
      );
      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MidtransPaymentSheet(
          payment: chargedPayment,
          onPaymentSuccess: _loadData,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to initialize GoPay/QRIS: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_payments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 64,
                minWidth: constraints.maxWidth - 40,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.iconBadgeBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        size: 38,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No invoices yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'When your room billing or rent invoices are issued, they will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final activePayment = _payments.first;
    final paymentHistory = _payments.length > 1
        ? _payments.sublist(1)
        : <PaymentModel>[];

    final roomNumber =
        activePayment.room?.roomNumber ??
        _activeBooking?.room?.roomNumber ??
        '-';
    final roomType =
        activePayment.room?.roomType ?? _activeBooking?.room?.roomType ?? '-';
    final monthLabel = Formatters.formatMonthYear(activePayment.dueDate);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          monthLabel,
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
                      KosMateStatusChip.fromPaymentStatus(activePayment.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    Formatters.formatCurrency(activePayment.amount),
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Due ${Formatters.formatDate(activePayment.dueDate)}',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  if (activePayment.status == PaymentStatus.pending) ...[
                    const Divider(height: 24),
                    QrisPaymentCard(
                    payment: activePayment,
                    onPayPressed: () => _startMidtransPayment(activePayment),
                    onSubmitReceiptPressed: () => showSubmitReceiptDialog(
                      context,
                      payment: activePayment,
                      onSubmitted: _loadData,
                    ),
                  ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bill information',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBillRow('Assigned room', roomNumber),
                  const SizedBox(height: 8),
                  _buildBillRow('Room type', roomType),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Payment simulation only. Integrated with Midtrans Sandbox.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),

            if (activePayment.status == PaymentStatus.pending) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submitted for owner review',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pending until payment settlement or owner confirms receipt.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text(
              'Payment history',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 12),

            if (paymentHistory.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'No previous payment records.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              )
            else ...[
              KosMateSearchField(
                controller: _historySearchController,
                hintText: 'Search by month, room, or amount...',
                onChanged: (val) => setState(() {
                  _historySearchQuery = val.trim();
                  _historyPage = 1;
                }),
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final sortOptions = [
                    KosMateSortOption<PaymentModel>(
                      id: 'due_desc',
                      label: 'Due Date (Newest)',
                      comparator: (a, b) => b.dueDate.compareTo(a.dueDate),
                    ),
                    KosMateSortOption<PaymentModel>(
                      id: 'due_asc',
                      label: 'Due Date (Oldest)',
                      comparator: (a, b) => a.dueDate.compareTo(b.dueDate),
                    ),
                    KosMateSortOption<PaymentModel>(
                      id: 'amount_desc',
                      label: 'Amount: High to Low',
                      comparator: (a, b) => b.amount.compareTo(a.amount),
                    ),
                    KosMateSortOption<PaymentModel>(
                      id: 'amount_asc',
                      label: 'Amount: Low to High',
                      comparator: (a, b) => a.amount.compareTo(b.amount),
                    ),
                  ];

                  final filteredHistory = paymentHistory.where((p) {
                    if (_historyStatusFilter != 'All') {
                      if (_historyStatusFilter == 'Pending' &&
                          p.status != PaymentStatus.pending) {
                        return false;
                      }
                      if (_historyStatusFilter == 'Paid' &&
                          p.status != PaymentStatus.paid) {
                        return false;
                      }
                      if (_historyStatusFilter == 'Overdue' &&
                          p.status != PaymentStatus.overdue) {
                        return false;
                      }
                      if (_historyStatusFilter == 'Cancelled' &&
                          p.status != PaymentStatus.cancelled) {
                        return false;
                      }
                    }

                    if (_historySearchQuery.isNotEmpty) {
                      final q = _historySearchQuery.toLowerCase();
                      final m = Formatters.formatMonthYear(p.dueDate)
                          .toLowerCase();
                      final amt = p.amount.toString();
                      final rm = p.room?.roomNumber.toLowerCase() ?? '';
                      return m.contains(q) || amt.contains(q) || rm.contains(q);
                    }
                    return true;
                  }).toList();

                  final selectedSort = sortOptions.firstWhere(
                    (s) => s.id == _historySortId,
                    orElse: () => sortOptions.first,
                  );
                  filteredHistory.sort(selectedSort.comparator);

                  final paged = paginateList(
                    filteredHistory,
                    _historyPage,
                    _historyPageSize,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KosMateFilterSortBar<PaymentModel>(
                        filterOptions: const [
                          'All',
                          'Pending',
                          'Paid',
                          'Overdue',
                          'Cancelled',
                        ],
                        selectedFilter: _historyStatusFilter,
                        onFilterChanged: (val) => setState(() {
                          _historyStatusFilter = val;
                          _historyPage = 1;
                        }),
                        sortOptions: sortOptions,
                        selectedSortId: _historySortId,
                        onSortChanged: (val) => setState(() {
                          _historySortId = val;
                          _historyPage = 1;
                        }),
                        totalCount: filteredHistory.length,
                        itemLabel: filteredHistory.length == 1
                            ? 'invoice'
                            : 'invoices',
                      ),
                      const SizedBox(height: 10),
                      if (filteredHistory.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'No invoices match your filter.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        )
                      else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: paged.pageItems.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final p = paged.pageItems[i];
                            final pMonth = Formatters.formatMonthYear(
                              p.dueDate,
                            );
                            final paidDateStr = p.paidDate != null
                                ? 'Paid ${Formatters.formatShortDate(p.paidDate)}'
                                : 'Due ${Formatters.formatShortDate(p.dueDate)}';

                            return InkWell(
                              onTap: () => PaymentDetailSheet.show(
                                context,
                                p,
                                onPayNow:
                                    p.status != PaymentStatus.paid &&
                                        p.status != PaymentStatus.cancelled
                                    ? () => _startMidtransPayment(p)
                                    : null,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.borderLight,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppTheme.iconBadgeBackground,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_outlined,
                                        color: AppTheme.accentColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pMonth,
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.foregroundColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            paidDateStr,
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
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        KosMateStatusChip.fromPaymentStatus(
                                          p.status,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          Formatters.formatCurrency(p.amount),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        KosMatePaginationBar(
                          currentPage: paged.safePage,
                          totalPages: paged.totalPages,
                          totalItems: filteredHistory.length,
                          startIndex: paged.startIndex,
                          endIndex: paged.endIndex,
                          pageSize: _historyPageSize,
                          onPageChanged: (p) =>
                              setState(() => _historyPage = p),
                          onPageSizeChanged: (s) => setState(() {
                            _historyPageSize = s;
                            _historyPage = 1;
                          }),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
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
