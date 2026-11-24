import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../models/payment_model.dart';
import 'admin_payment_form_screen.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final _paymentService = sl.payment;
  final _searchController = TextEditingController();

  List<PaymentModel> _allPayments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';

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
      final payments = await _paymentService.getAllPayments();
      if (mounted) {
        setState(() {
          _allPayments = payments;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPaymentForm([PaymentModel? payment]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPaymentFormScreen(payment: payment),
      ),
    );
    if (changed == true && mounted) {
      _loadPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allPayments.where((p) {
      if (_selectedStatusFilter != 'All') {
        if (_selectedStatusFilter == 'Pending' &&
            p.status != PaymentStatus.pending) {
          return false;
        }
        if (_selectedStatusFilter == 'Paid' && p.status != PaymentStatus.paid) {
          return false;
        }
        if (_selectedStatusFilter == 'Overdue' &&
            p.status != PaymentStatus.overdue) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final tenant = p.user?.name.toLowerCase() ?? '';
        final room = p.room?.roomNumber.toLowerCase() ?? '';
        final house = p.room?.house?.houseName.toLowerCase() ?? '';
        return tenant.contains(q) || room.contains(q) || house.contains(q);
      }
      return true;
    }).toList();

    final totalCount = _allPayments.length;
    final pendingCount = _allPayments
        .where((p) => p.status == PaymentStatus.pending)
        .length;
    final overdueCount = _allPayments
        .where((p) => p.status == PaymentStatus.overdue)
        .length;
    final paidCount = _allPayments
        .where((p) => p.status == PaymentStatus.paid)
        .length;

    return Scaffold(
      appBar: const KosMateAppBar(
        title: 'Platform Payments',
        showBackButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPaymentForm(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPayments,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header title
                    const Text(
                      'All Invoices & Payments',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Admin overview of all tenant transactions across boarding houses',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Summary Counters Strip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                            'Total',
                            '$totalCount',
                            AppTheme.primaryColor,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppTheme.borderMedium,
                          ),
                          _buildStatColumn(
                            'Paid',
                            '$paidCount',
                            AppTheme.successColor,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppTheme.borderMedium,
                          ),
                          _buildStatColumn(
                            'Pending',
                            '$pendingCount',
                            AppTheme.warningColor,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppTheme.borderMedium,
                          ),
                          _buildStatColumn(
                            'Overdue',
                            '$overdueCount',
                            AppTheme.destructiveColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Search Field
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search tenant, room, or house...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: AppTheme.textMuted,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.borderMedium,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppTheme.borderMedium,
                          ),
                        ),
                      ),
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 10),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Pending', 'Paid', 'Overdue'].map((
                          f,
                        ) {
                          final isSelected = _selectedStatusFilter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: isSelected,
                              showCheckmark: false,
                              checkmarkColor: AppTheme.accentColor,
                              selectedColor: AppTheme.primaryLight,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: isSelected
                                    ? AppTheme.accentColor
                                    : AppTheme.borderMedium,
                              ),
                              labelStyle: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: isSelected
                                    ? AppTheme.accentColor
                                    : AppTheme.textDark,
                              ),
                              onSelected: (_) {
                                setState(() => _selectedStatusFilter = f);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Payments List
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No payment records found.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final p = filtered[idx];
                          return _buildPaymentTile(p);
                        },
                      ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTile(PaymentModel p) {
    Color badgeBg;
    Color badgeText;
    switch (p.status) {
      case PaymentStatus.paid:
        badgeBg = AppTheme.successLight;
        badgeText = AppTheme.successColor;
        break;
      case PaymentStatus.pending:
        badgeBg = AppTheme.warningLight;
        badgeText = AppTheme.warningColor;
        break;
      case PaymentStatus.overdue:
        badgeBg = AppTheme.destructiveLight;
        badgeText = AppTheme.destructiveColor;
        break;
      case PaymentStatus.cancelled:
        badgeBg = AppTheme.surfaceLight;
        badgeText = AppTheme.textMuted;
        break;
    }

    final tenantName = p.user?.name ?? 'User #${p.userId}';
    final roomNumber = p.room?.roomNumber ?? 'Room #${p.roomId}';
    final houseName = p.room?.house?.houseName ?? 'House';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPaymentForm(p),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBadgeBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppTheme.accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              tenantName,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.foregroundColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.status.displayName,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: badgeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Room $roomNumber • $houseName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            Formatters.formatCurrency(p.amount),
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Text(
                            'Due: ${Formatters.formatDate(p.dueDate)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSubtle,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
