import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';
import '../complaints/owner_complaints_screen.dart';

class OwnerManagementHubTab extends StatefulWidget {
  final UserModel user;

  const OwnerManagementHubTab({super.key, required this.user});

  @override
  State<OwnerManagementHubTab> createState() => _OwnerManagementHubTabState();
}

class _OwnerManagementHubTabState extends State<OwnerManagementHubTab> {
  final _houseService = sl.house;
  final _roomService = sl.room;
  final _paymentService = sl.payment;
  final _complaintService = sl.complaint;
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String _searchQuery = '';

  List<BookingModel> _occupiedBookings = [];
  List<PaymentModel> _allPayments = [];
  List<ComplaintModel> _allComplaints = [];

  // Grouped maps for fast tenant inspector access
  Map<int, List<ComplaintModel>> _complaintsByTenant = {};
  Map<int, List<PaymentModel>> _paymentsByTenant = {};

  @override
  void initState() {
    super.initState();
    _loadManagementData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadManagementData() async {
    setState(() => _isLoading = true);
    try {
      final ownerId = widget.user.userId;

      final houses = await _houseService.getHousesByOwner(ownerId);

      final allRooms = <RoomModel>[];
      for (final h in houses) {
        final rooms = await _roomService.getRooms(houseId: h.houseId);
        allRooms.addAll(rooms);
      }

      // Fetch active approved bookings
      final List<BookingModel> activeBookings = [];
      if (allRooms.isNotEmpty) {
        try {
          final roomIds = allRooms.map((r) => r.roomId).toList();
          final bookingRes = await supabase
              .from(SupabaseConstants.bookingTable)
              .select('*, users!booking_user_id_fkey(*)')
              .inFilter('room_id', roomIds)
              .eq('status', BookingStatus.approved.name);

          for (final row in bookingRes as List) {
            final b = BookingModel.fromJson(row as Map<String, dynamic>);
            // Attach house & room information
            final matchedRoom = allRooms.where((r) => r.roomId == b.roomId);
            if (matchedRoom.isNotEmpty) {
              final r = matchedRoom.first;
              final matchedHouse = houses.where((h) => h.houseId == r.houseId);
              final houseObj = matchedHouse.isNotEmpty
                  ? matchedHouse.first
                  : null;
              final fullRoom = r.copyWith(house: houseObj);
              activeBookings.add(b.copyWith(room: fullRoom));
            } else {
              activeBookings.add(b);
            }
          }
        } catch (_) {}
      }
      _occupiedBookings = activeBookings;

      // Fetch payments
      final payments = await _paymentService.getPaymentsForOwner(ownerId);
      _allPayments = payments;
      final Map<int, List<PaymentModel>> paymentMap = {};
      for (final p in payments) {
        paymentMap.putIfAbsent(p.userId, () => []).add(p);
      }
      _paymentsByTenant = paymentMap;

      // Fetch complaints
      final complaints = await _complaintService.getComplaintsForOwner(ownerId);
      _allComplaints = complaints;
      final Map<int, List<ComplaintModel>> complaintMap = {};
      for (final c in complaints) {
        complaintMap.putIfAbsent(c.userId, () => []).add(c);
      }
      _complaintsByTenant = complaintMap;

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openComplaintsManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerComplaintsScreen(owner: widget.user),
      ),
    ).then((_) {
      if (mounted) _loadManagementData();
    });
  }

  void _openPaymentsManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllPaymentsSheet(
        payments: _allPayments,
        onPaymentUpdated: () {
          _loadManagementData();
        },
      ),
    );
  }

  void _openTenantInspector(BookingModel booking) {
    final tenant = booking.user;
    if (tenant == null) return;

    final tenantComplaints = _complaintsByTenant[tenant.userId] ?? [];
    final tenantPayments = _paymentsByTenant[tenant.userId] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TenantInspectorSheet(
        booking: booking,
        complaints: tenantComplaints,
        payments: tenantPayments,
        onDataChanged: _loadManagementData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Compute top summary badges
    final activeComplaintsCount = _allComplaints
        .where((c) => c.status != ComplaintStatus.resolved)
        .length;
    final unpaidPaymentsCount = _allPayments
        .where(
          (p) =>
              p.status == PaymentStatus.pending ||
              p.status == PaymentStatus.overdue,
        )
        .length;

    // Filter occupied tenants
    final filteredBookings = _occupiedBookings.where((b) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nameMatch = b.user?.name.toLowerCase().contains(q) ?? false;
      final phoneMatch = b.user?.phone.toLowerCase().contains(q) ?? false;
      final roomMatch =
          b.room?.roomNumber.toLowerCase().contains(q) ??
          b.roomId.toString().contains(q);
      final houseMatch =
          b.room?.house?.houseName.toLowerCase().contains(q) ?? false;
      return nameMatch || phoneMatch || roomMatch || houseMatch;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadManagementData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Cards: See Every Complaints & See Every Payments
            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    title: 'See every\ncomplaint',
                    countText: '${_allComplaints.length} Total',
                    badgeText: activeComplaintsCount > 0
                        ? '$activeComplaintsCount Open'
                        : 'All Resolved',
                    badgeColor: activeComplaintsCount > 0
                        ? AppTheme.warningLight
                        : AppTheme.successLight,
                    badgeTextColor: activeComplaintsCount > 0
                        ? AppTheme.warningColor
                        : AppTheme.successColor,
                    icon: Icons.build_circle_outlined,
                    onTap: _openComplaintsManagement,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverviewCard(
                    title: 'See every\npayment',
                    countText: '${_allPayments.length} Invoices',
                    badgeText: unpaidPaymentsCount > 0
                        ? '$unpaidPaymentsCount Unpaid'
                        : 'Up to Date',
                    badgeColor: unpaidPaymentsCount > 0
                        ? AppTheme.destructiveLight
                        : AppTheme.successLight,
                    badgeTextColor: unpaidPaymentsCount > 0
                        ? AppTheme.destructiveColor
                        : AppTheme.successColor,
                    icon: Icons.receipt_long_outlined,
                    onTap: _openPaymentsManagement,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section Header: Occupied Tenants
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Occupied Tenants',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foregroundColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_occupiedBookings.length} Active',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tenant name, room, or house...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                          color: AppTheme.textMuted,
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
                  borderSide: const BorderSide(color: AppTheme.borderMedium),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.borderMedium),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppTheme.accentColor,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 16),

            // Occupied Tenants List
            if (_occupiedBookings.isEmpty)
              _buildEmptyTenantsState()
            else if (filteredBookings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No occupied tenants match your search.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredBookings.length,
                itemBuilder: (context, idx) {
                  final booking = filteredBookings[idx];
                  final tenant = booking.user;
                  final tenantId = tenant?.userId ?? 0;
                  final openComplaints = (_complaintsByTenant[tenantId] ?? [])
                      .where((c) => c.status != ComplaintStatus.resolved)
                      .length;
                  final hasUnpaid = (_paymentsByTenant[tenantId] ?? []).any(
                    (p) =>
                        p.status == PaymentStatus.pending ||
                        p.status == PaymentStatus.overdue,
                  );

                  return _buildTenantCard(
                    booking: booking,
                    openComplaintsCount: openComplaints,
                    hasUnpaidPayment: hasUnpaid,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String countText,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderLight, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.iconBadgeBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: AppTheme.accentColor, size: 20),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.textSubtle,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foregroundColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                countText,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTenantCard({
    required BookingModel booking,
    required int openComplaintsCount,
    required bool hasUnpaidPayment,
  }) {
    final tenant = booking.user;
    final tenantName = tenant?.name ?? 'Tenant';
    final room = booking.room;
    final roomNumber = room?.roomNumber ?? 'Room ${booking.roomId}';
    final houseName = room?.house?.houseName ?? 'House';
    final phone = tenant?.phone ?? 'No phone provided';

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
          onTap: () => _openTenantInspector(booking),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                // Tenant Avatar / Initials
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryLight,
                  child: Text(
                    tenantName.isNotEmpty ? tenantName[0].toUpperCase() : 'T',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Tenant Info
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
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              roomNumber,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        houseName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const Spacer(),
                          if (openComplaintsCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warningLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$openComplaintsCount complaint${openComplaintsCount > 1 ? "s" : ""}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warningColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (hasUnpaidPayment) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.destructiveLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Payment Due',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.destructiveColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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

  Widget _buildEmptyTenantsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 44,
                color: AppTheme.accentColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Occupied Tenants Yet',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'When tenants book and occupy your boarding rooms, their details, complaints, and invoices will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// TENANT INSPECTOR BOTTOM SHEET
// -------------------------------------------------------------
class _TenantInspectorSheet extends StatefulWidget {
  final BookingModel booking;
  final List<ComplaintModel> complaints;
  final List<PaymentModel> payments;
  final VoidCallback onDataChanged;

  const _TenantInspectorSheet({
    required this.booking,
    required this.complaints,
    required this.payments,
    required this.onDataChanged,
  });

  @override
  State<_TenantInspectorSheet> createState() => _TenantInspectorSheetState();
}

class _TenantInspectorSheetState extends State<_TenantInspectorSheet> {
  final _complaintService = sl.complaint;
  final _paymentService = sl.payment;

  void _showComplaintResponseDialog(ComplaintModel complaint) {
    final responseCtrl = TextEditingController(text: complaint.response ?? '');
    ComplaintStatus selectedStatus = complaint.status == ComplaintStatus.pending
        ? ComplaintStatus.inProgress
        : complaint.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(complaint.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description:\n${complaint.description}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ComplaintStatus>(
                  isExpanded: true,
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: ComplaintStatus.inProgress,
                      child: Text('In Progress'),
                    ),
                    DropdownMenuItem(
                      value: ComplaintStatus.resolved,
                      child: Text('Resolved'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedStatus = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: responseCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Response / Note',
                    hintText: 'e.g. Technician arrived and fixed.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  await _complaintService.respondToComplaint(
                    complaintId: complaint.complaintId,
                    responseText: responseCtrl.text.trim(),
                    status: selectedStatus,
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  widget.onDataChanged();
                } catch (_) {}
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _markPaymentPaid(PaymentModel payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Mark invoice of ${Formatters.formatCurrency(payment.amount)} as paid?',
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
              // Drag handle
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

              // Sheet content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  children: [
                    // Tenant Profile Header
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

                    // Occupied Room Card
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
                            'OCCUPIED ROOM',
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
                              Text(
                                room?.roomNumber ??
                                    'Room ${widget.booking.roomId}',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.foregroundColor,
                                ),
                              ),
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

                    // Complaints Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Complaints',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.foregroundColor,
                          ),
                        ),
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

                    // Payments Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment History',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.foregroundColor,
                          ),
                        ),
                        Text(
                          '${widget.payments.length} invoices',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    'PAID',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.successColor,
                                    ),
                                  ),
                                ),
                            ],
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

// -------------------------------------------------------------
// ALL PAYMENTS SHEET (When clicking "See every payment")
// -------------------------------------------------------------
class _AllPaymentsSheet extends StatefulWidget {
  final List<PaymentModel> payments;
  final VoidCallback onPaymentUpdated;

  const _AllPaymentsSheet({
    required this.payments,
    required this.onPaymentUpdated,
  });

  @override
  State<_AllPaymentsSheet> createState() => _AllPaymentsSheetState();
}

class _AllPaymentsSheetState extends State<_AllPaymentsSheet> {
  final _paymentService = sl.payment;
  String _selectedFilter = 'All';
  String _search = '';

  void _markPaid(PaymentModel payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Mark invoice of ${Formatters.formatCurrency(payment.amount)} as paid?',
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
                    const Text(
                      'All Invoices & Payments',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppTheme.foregroundColor,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: ['All', 'Pending', 'Paid', 'Overdue'].map((f) {
                    final selected = _selectedFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: selected,
                        selectedColor: AppTheme.primaryLight,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected
                              ? AppTheme.accentColor
                              : AppTheme.borderMedium,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selected
                              ? AppTheme.accentColor
                              : AppTheme.textDark,
                        ),
                        onSelected: (_) => setState(() => _selectedFilter = f),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search tenant or room...',
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _search = val.trim()),
                ),
              ),
              const SizedBox(height: 8),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No payment records found.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, idx) {
                          final p = filtered[idx];
                          final isPaid = p.status == PaymentStatus.paid;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderLight),
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
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Formatters.formatCurrency(p.amount),
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentColor,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Mark Paid',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
