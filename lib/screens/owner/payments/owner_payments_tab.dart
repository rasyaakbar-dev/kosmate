import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/payment_model.dart';
import '../../../models/user_model.dart';
import '../../../services/payment_service.dart';

class OwnerPaymentsTab extends StatefulWidget {
  final UserModel user;

  const OwnerPaymentsTab({super.key, required this.user});

  @override
  State<OwnerPaymentsTab> createState() => _OwnerPaymentsTabState();
}

class _OwnerPaymentsTabState extends State<OwnerPaymentsTab> {
  final _paymentService = PaymentService();
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                    _applyFilter();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search payment or renter',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _applyFilter();
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
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
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 56,
                            color: Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No payments found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Payment records will show up here as rent invoices are issued.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
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

                      String dateInfo;
                      if (p.status == PaymentStatus.paid) {
                        dateInfo = p.paidDate != null
                            ? 'Paid on ${Formatters.formatDate(p.paidDate)}'
                            : 'Paid';
                      } else {
                        dateInfo = 'Due on ${Formatters.formatDate(p.dueDate)}';
                      }

                      final subtitle = '$roomNumber • $dateInfo';

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
                                    _buildStatusPill(p.status),
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

  Widget _buildStatusPill(PaymentStatus status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case PaymentStatus.paid:
        bg = const Color(0xFFE6F4EA);
        text = const Color(0xFF1E7E34);
        label = 'Paid';
        break;
      case PaymentStatus.pending:
        bg = const Color(0xFFFEF9E7);
        text = const Color(0xFFB45309);
        label = 'Pending';
        break;
      case PaymentStatus.overdue:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        label = 'Overdue';
        break;
      case PaymentStatus.cancelled:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}
