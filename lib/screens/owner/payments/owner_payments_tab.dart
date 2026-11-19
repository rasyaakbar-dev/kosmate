import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/payment_model.dart';
import '../../../models/user_model.dart';

class OwnerPaymentsTab extends StatefulWidget {
  final UserModel user;

  const OwnerPaymentsTab({super.key, required this.user});

  @override
  State<OwnerPaymentsTab> createState() => _OwnerPaymentsTabState();
}

class _OwnerPaymentsTabState extends State<OwnerPaymentsTab> {
  final _paymentService = sl.payment;
  final _searchController = TextEditingController();

  List<PaymentModel> _allPayments = [];
  List<PaymentModel> _filteredPayments = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final payments = await _paymentService.getPaymentsForOwner(
        widget.user.userId,
      );
      if (mounted) {
        setState(() {
          _allPayments = payments;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter() {
    var list = List<PaymentModel>.from(_allPayments);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final tenant = p.user?.name.toLowerCase() ?? '';
        final room = p.room?.roomNumber.toLowerCase() ?? '';
        final amount = p.amount.toString();
        return tenant.contains(q) || room.contains(q) || amount.contains(q);
      }).toList();
    }

    _filteredPayments = list;
  }

  Future<void> _confirmPaymentPaid(PaymentModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Mark invoice #${p.paymentId} for ${p.user?.name ?? "tenant"} (${Formatters.formatCurrency(p.amount)}) as paid?',
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
          paymentId: p.paymentId,
          status: PaymentStatus.paid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment status updated to Paid.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPayments();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update payment: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalCount = _filteredPayments.length;
    final pendingCount = _filteredPayments
        .where((p) => p.status == PaymentStatus.pending)
        .length;

    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: Column(
        children: [
          // Top search input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: KosMateSearchBar(
              controller: _searchController,
              hintText: 'Search payment or renter',
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                  _applyFilter();
                });
              },
              onClear: () {
                setState(() {
                  _searchQuery = '';
                  _applyFilter();
                });
              },
            ),
          ),

          // Count & pending subtitle row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalCount payments • $pendingCount pending',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Payments List
          Expanded(
            child: _filteredPayments.isEmpty
                ? const KosMateEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No payments found',
                    subtitle: 'Payment records will show up here as rent invoices are issued.',
                    plain: true,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    itemCount: _filteredPayments.length,
                    itemBuilder: (context, index) {
                      final p = _filteredPayments[index];
                      final tenantName = p.user?.name ?? 'Tenant';
                      final roomNumber =
                          p.room?.roomNumber ?? 'Room ${p.roomId}';

                      final period = Formatters.formatMonthYear(
                        p.status == PaymentStatus.paid ? p.paidDate : p.dueDate,
                      );
                      final dateInfo = p.status == PaymentStatus.paid
                          ? p.paidDate != null
                                ? 'Paid on ${Formatters.formatShortDate(p.paidDate)}'
                                : 'Paid'
                          : 'Due on ${Formatters.formatShortDate(p.dueDate)}';

                      final subtitle = '$roomNumber • $period • $dateInfo';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.1,
                          ),
                        ),
                        child: InkWell(
                          onTap: p.status == PaymentStatus.pending
                              ? () => _confirmPaymentPaid(p)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_outlined,
                                    color: AppTheme.accentColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tenantName,
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitle,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    KosMateStatusChip.fromPaymentStatus(
                                      p.status,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      Formatters.formatCurrency(p.amount),
                                      style: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
