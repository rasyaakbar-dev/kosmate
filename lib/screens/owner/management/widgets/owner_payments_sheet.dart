import 'package:flutter/material.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/list_controls.dart';
import '../../../../core/widgets/payment_detail_sheet.dart';
import '../../../../core/widgets/private_storage_image.dart';
import '../../../../models/payment_model.dart';

class OwnerPaymentsSheet extends StatefulWidget {
  final List<PaymentModel> payments;
  final VoidCallback onPaymentUpdated;
  final VoidCallback? onIssueInvoice;

  const OwnerPaymentsSheet({
    super.key,
    required this.payments,
    required this.onPaymentUpdated,
    this.onIssueInvoice,
  });

  @override
  State<OwnerPaymentsSheet> createState() => OwnerPaymentsSheetState();
}

class OwnerPaymentsSheetState extends State<OwnerPaymentsSheet> {
  final _paymentService = sl.payment;
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _search = '';
  String _sortId = 'due_desc';
  int _page = 1;
  int _pageSize = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _markPaid(PaymentModel payment) async {
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
        widget.onPaymentUpdated();
        if (mounted) Navigator.pop(context);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
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
      KosMateSortOption<PaymentModel>(
        id: 'tenant_asc',
        label: 'Tenant (A–Z)',
        comparator: (a, b) => (a.user?.name ?? '').toLowerCase().compareTo(
          (b.user?.name ?? '').toLowerCase(),
        ),
      ),
    ];

    final filtered = widget.payments.where((p) {
      if (_selectedFilter == 'Pending' && p.status != PaymentStatus.pending) {
        return false;
      }
      if (_selectedFilter == 'Paid' && p.status != PaymentStatus.paid) {
        return false;
      }
      if (_selectedFilter == 'Overdue' && p.status != PaymentStatus.overdue) {
        return false;
      }

      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final name = p.user?.name.toLowerCase() ?? '';
        final room = p.room?.roomNumber.toLowerCase() ?? '';
        return name.contains(q) || room.contains(q);
      }
      return true;
    }).toList();

    final selectedSort = sortOptions.firstWhere(
      (s) => s.id == _sortId,
      orElse: () => sortOptions.first,
    );
    filtered.sort(selectedSort.comparator);

    final paged = paginateList(filtered, _page, _pageSize);

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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'All Invoices & Payments',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 18,
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
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppTheme.textMuted,
                          ),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: KosMateSearchField(
                  controller: _searchController,
                  hintText: 'Search tenant or room...',
                  fillColor: AppTheme.surfaceLight,
                  onChanged: (val) => setState(() {
                    _search = val.trim();
                    _page = 1;
                  }),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: KosMateFilterSortBar<PaymentModel>(
                  filterOptions: const ['All', 'Pending', 'Paid', 'Overdue'],
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (f) => setState(() {
                    _selectedFilter = f;
                    _page = 1;
                  }),
                  sortOptions: sortOptions,
                  selectedSortId: _sortId,
                  onSortChanged: (s) => setState(() {
                    _sortId = s;
                    _page = 1;
                  }),
                  totalCount: filtered.length,
                  itemLabel: filtered.length == 1 ? 'invoice' : 'invoices',
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No payment records found.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              itemCount: paged.pageItems.length,
                              itemBuilder: (ctx, idx) {
                                final p = paged.pageItems[idx];
                                final isPaid = p.status == PaymentStatus.paid;
                                return InkWell(
                                  onTap: () => PaymentDetailSheet.show(
                                    context,
                                    p,
                                    onMarkPaid: !isPaid
                                        ? () => _markPaid(p)
                                        : null,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppTheme.borderLight,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: isPaid
                                              ? AppTheme.successLight
                                              : AppTheme.destructiveLight,
                                          child: Icon(
                                            isPaid
                                                ? Icons.check
                                                : Icons.receipt_outlined,
                                            size: 16,
                                            color: isPaid
                                                ? AppTheme.successColor
                                                : AppTheme.destructiveColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.user?.name ?? 'Tenant',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                'Room ${p.room?.roomNumber ?? p.roomId} • Due ${Formatters.formatDate(p.dueDate)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              Formatters.formatCurrency(
                                                p.amount,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (!isPaid) ...[
                                              const SizedBox(height: 4),
                                              GestureDetector(
                                                onTap: () => _markPaid(p),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.accentColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Mark Paid',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          KosMatePaginationBar(
                            currentPage: paged.safePage,
                            totalPages: paged.totalPages,
                            totalItems: filtered.length,
                            startIndex: paged.startIndex,
                            endIndex: paged.endIndex,
                            pageSize: _pageSize,
                            onPageChanged: (p) => setState(() => _page = p),
                            onPageSizeChanged: (s) => setState(() {
                              _pageSize = s;
                              _page = 1;
                            }),
                          ),
                          const SizedBox(height: 12),
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
