import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/list_controls.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../core/widgets/complaint_response_sheet.dart';
import '../../../core/widgets/payment_detail_sheet.dart';
import '../../../core/widgets/private_storage_image.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';

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
  final _bookingService = sl.booking;
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String _searchQuery = '';

  List<BookingModel> _occupiedBookings = [];
  List<BookingModel> _pendingBookings = [];
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

      // Fetch active approved bookings and pending booking requests
      final List<BookingModel> activeBookings = [];
      final List<BookingModel> pendingBookings = [];
      if (allRooms.isNotEmpty) {
        try {
          final roomIds = allRooms.map((r) => r.roomId).toList();
          final bookings = await _bookingService.getBookingsByRoomIds(roomIds);

          for (final b in bookings) {
            final matchedRoom = allRooms.where((r) => r.roomId == b.roomId);
            BookingModel fullBooking = b;
            if (matchedRoom.isNotEmpty) {
              final r = matchedRoom.first;
              final matchedHouse = houses.where((h) => h.houseId == r.houseId);
              final houseObj = matchedHouse.isNotEmpty
                  ? matchedHouse.first
                  : null;
              final fullRoom = r.copyWith(house: houseObj);
              fullBooking = b.copyWith(room: fullRoom);
            }

            if (b.status == BookingStatus.approved) {
              activeBookings.add(fullBooking);
            } else if (b.status == BookingStatus.pending) {
              pendingBookings.add(fullBooking);
            }
          }
        } catch (_) {}
      }
      _occupiedBookings = activeBookings;
      _pendingBookings = pendingBookings;

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

  Future<void> _approveBooking(BookingModel booking) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _bookingService.updateBookingStatus(
        bookingId: booking.bookingId,
        status: BookingStatus.approved,
      );

      final roomPrice = booking.room?.price ?? 0.0;
      if (roomPrice > 0) {
        try {
          await _paymentService.createPayment(
            userId: booking.userId,
            roomId: booking.roomId,
            amount: roomPrice,
            dueDate: booking.requestDate.add(const Duration(days: 7)),
          );
        } catch (_) {}
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Booking approved! Initial invoice created.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      _loadManagementData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to approve booking: $e'),
          backgroundColor: AppTheme.destructiveColor,
        ),
      );
    }
  }

  Future<void> _rejectBooking(BookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Booking Request'),
        content: Text(
          'Are you sure you want to reject booking request for Room ${booking.room?.roomNumber ?? booking.roomId} by ${booking.user?.name ?? "tenant"}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructiveColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _bookingService.updateBookingStatus(
          bookingId: booking.bookingId,
          status: BookingStatus.rejected,
        );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Booking request rejected.'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        _loadManagementData();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to reject booking: $e'),
            backgroundColor: AppTheme.destructiveColor,
          ),
        );
      }
    }
  }

  void _showIssueInvoiceDialog({BookingModel? preselectedBooking}) {
    if (_occupiedBookings.isEmpty && preselectedBooking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active tenants available to issue an invoice to.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    BookingModel selectedBooking =
        preselectedBooking ?? _occupiedBookings.first;
    final amountController = TextEditingController(
      text: selectedBooking.room?.price.toInt().toString() ?? '',
    );
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Issue Invoice to Tenant',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Tenant / Room',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<BookingModel>(
                    isExpanded: true,
                    initialValue: selectedBooking,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: _occupiedBookings.map((b) {
                      final name = b.user?.name ?? 'Tenant';
                      final room = b.room?.roomNumber ?? 'Room ${b.roomId}';
                      return DropdownMenuItem(
                        value: b,
                        child: Text(
                          '$name • $room',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedBooking = val;
                          amountController.text =
                              val.room?.price.toInt().toString() ?? '';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Invoice Amount (Rp) *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter an amount';
                      }
                      if (double.tryParse(v.trim()) == null ||
                          double.parse(v.trim()) <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Payment Due Date *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderMedium),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(Formatters.formatDate(dueDate)),
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: AppTheme.accentColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final amount = double.parse(amountController.text.trim());
                  await _paymentService.createPayment(
                    userId: selectedBooking.userId,
                    roomId: selectedBooking.roomId,
                    amount: amount,
                    dueDate: dueDate,
                  );
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Invoice issued successfully!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                  _loadManagementData();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Issue Invoice'),
            ),
          ],
        ),
      ),
    );
  }

  void _openComplaintsManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ComplaintsSheet(ownerId: widget.user.userId),
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
        onIssueInvoice: () {
          Navigator.pop(ctx);
          _showIssueInvoiceDialog();
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
        onIssueInvoice: () {
          Navigator.pop(ctx);
          _showIssueInvoiceDialog(preselectedBooking: booking);
        },
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

            // Pending Booking Requests Section (if any pending requests exist)
            if (_pendingBookings.isNotEmpty) ...[
              _buildPendingBookingsSection(),
              const SizedBox(height: 24),
            ],

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
                          color: AppTheme.destructiveColor,
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

  Widget _buildPendingBookingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pending Booking Requests',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_pendingBookings.length} Action Needed',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.warningColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._pendingBookings.map((b) => _buildPendingBookingCard(b)),
      ],
    );
  }

  Widget _buildPendingBookingCard(BookingModel b) {
    final tenant = b.user;
    final room = b.room;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warningLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.warningLight,
                backgroundImage:
                    tenant?.avatarUrl != null && tenant!.avatarUrl!.isNotEmpty
                    ? NetworkImage(tenant.avatarUrl!)
                    : null,
                child: tenant?.avatarUrl == null || tenant!.avatarUrl!.isEmpty
                    ? Text(
                        tenant?.name.isNotEmpty == true
                            ? tenant!.name[0].toUpperCase()
                            : 'T',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant?.name ?? 'Tenant Request',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${room?.house?.houseName ?? "Boarding House"} • ${room?.roomNumber ?? "Room ${b.roomId}"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (room?.price != null)
                Text(
                  '${Formatters.formatCurrency(room!.price)}/mo',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Desired Move-in: ${Formatters.formatDate(b.requestDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (b.notes != null && b.notes!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '• Note: ${b.notes!.trim()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _rejectBooking(b),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.destructiveColor,
                  side: const BorderSide(color: AppTheme.destructiveColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _approveBooking(b),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve & Invoice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
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
                          Flexible(
                            child: Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

class _TenantInspectorSheet extends StatefulWidget {
  final BookingModel booking;
  final List<ComplaintModel> complaints;
  final List<PaymentModel> payments;
  final VoidCallback onDataChanged;
  final VoidCallback? onIssueInvoice;

  const _TenantInspectorSheet({
    required this.booking,
    required this.complaints,
    required this.payments,
    required this.onDataChanged,
    this.onIssueInvoice,
  });

  @override
  State<_TenantInspectorSheet> createState() => _TenantInspectorSheetState();
}

class _TenantInspectorSheetState extends State<_TenantInspectorSheet> {
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

// ---------------------------------------------------------------------------
// _ComplaintsSheet — bottom-sheet version of OwnerComplaintsScreen
// ---------------------------------------------------------------------------

class _ComplaintsSheet extends StatefulWidget {
  final int ownerId;

  const _ComplaintsSheet({required this.ownerId});

  @override
  State<_ComplaintsSheet> createState() => _ComplaintsSheetState();
}

class _ComplaintsSheetState extends State<_ComplaintsSheet> {
  final _complaintService = sl.complaint;
  final _searchController = TextEditingController();

  List<ComplaintModel> _allComplaints = [];
  List<ComplaintModel> _filteredComplaints = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String _sortId = 'newest';
  int _page = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    try {
      final complaints = await _complaintService.getComplaintsForOwner(
        widget.ownerId,
      );
      if (mounted) {
        setState(() {
          _allComplaints = complaints;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<KosMateSortOption<ComplaintModel>> get _sortOptions => [
    KosMateSortOption<ComplaintModel>(
      id: 'newest',
      label: 'Newest',
      comparator: (a, b) => b.date.compareTo(a.date),
    ),
    KosMateSortOption<ComplaintModel>(
      id: 'oldest',
      label: 'Oldest',
      comparator: (a, b) => a.date.compareTo(b.date),
    ),
    KosMateSortOption<ComplaintModel>(
      id: 'priority',
      label: 'Priority (High–Low)',
      comparator: (a, b) => b.priority.index.compareTo(a.priority.index),
    ),
    KosMateSortOption<ComplaintModel>(
      id: 'room',
      label: 'Room # (A–Z)',
      comparator: (a, b) => (a.room?.roomNumber ?? '${a.roomId}')
          .toLowerCase()
          .compareTo((b.room?.roomNumber ?? '${b.roomId}').toLowerCase()),
    ),
  ];

  void _applyFilter() {
    var list = List<ComplaintModel>.from(_allComplaints);

    if (_selectedFilter == 'Open') {
      list = list.where((c) => c.status == ComplaintStatus.pending).toList();
    } else if (_selectedFilter == 'In Progress') {
      list = list.where((c) => c.status == ComplaintStatus.inProgress).toList();
    } else if (_selectedFilter == 'Resolved') {
      list = list.where((c) => c.status == ComplaintStatus.resolved).toList();
    } else if (_selectedFilter == 'Rejected') {
      list = list.where((c) => c.status == ComplaintStatus.rejected).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        final title = c.title.toLowerCase();
        final desc = c.description.toLowerCase();
        final tenant = c.user?.name.toLowerCase() ?? '';
        final room = c.room?.roomNumber.toLowerCase() ?? '';
        return title.contains(q) ||
            desc.contains(q) ||
            tenant.contains(q) ||
            room.contains(q);
      }).toList();
    }

    final selectedSort = _sortOptions.firstWhere(
      (s) => s.id == _sortId,
      orElse: () => _sortOptions.first,
    );
    list.sort(selectedSort.comparator);

    _filteredComplaints = list;
  }

  void _showComplaintResponseDialog(ComplaintModel complaint) {
    ComplaintResponseSheet.show(context, complaint, onUpdated: _loadComplaints);
  }

  @override
  Widget build(BuildContext context) {
    final paged = paginateList(_filteredComplaints, _page, _pageSize);
    final openCount = _allComplaints
        .where(
          (c) =>
              c.status == ComplaintStatus.pending ||
              c.status == ComplaintStatus.inProgress,
        )
        .length;

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
              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Complaints',
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
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: KosMateSearchField(
                  controller: _searchController,
                  hintText: 'Search by title, tenant, or room...',
                  fillColor: AppTheme.surfaceLight,
                  onChanged: (val) => setState(() {
                    _searchQuery = val.trim();
                    _page = 1;
                    _applyFilter();
                  }),
                ),
              ),
              const SizedBox(height: 10),
              // Filter + Sort bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: KosMateFilterSortBar<ComplaintModel>(
                  filterOptions: const [
                    'All',
                    'Open',
                    'In Progress',
                    'Resolved',
                    'Rejected',
                  ],
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (val) => setState(() {
                    _selectedFilter = val;
                    _page = 1;
                    _applyFilter();
                  }),
                  sortOptions: _sortOptions,
                  selectedSortId: _sortId,
                  onSortChanged: (val) => setState(() {
                    _sortId = val;
                    _page = 1;
                    _applyFilter();
                  }),
                  totalCount: _filteredComplaints.length,
                  itemLabel:
                      '${_filteredComplaints.length == 1 ? 'complaint' : 'complaints'} ($openCount Open)',
                ),
              ),
              const SizedBox(height: 6),
              // List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredComplaints.isEmpty
                    ? KosMateEmptyState(
                        icon: Icons.build_circle_outlined,
                        title: 'No complaints found',
                        subtitle: _selectedFilter != 'All'
                            ? 'No complaints match the "$_selectedFilter" filter.'
                            : 'Tenant maintenance tickets will appear here.',
                        plain: true,
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        itemCount: paged.pageItems.length,
                        itemBuilder: (context, index) {
                          final c = paged.pageItems[index];
                          final tenant = c.user?.name ?? 'Tenant';
                          final room = c.room?.roomNumber ?? 'Room ${c.roomId}';
                          final subtitle = '$tenant • $room';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: AppTheme.borderLight,
                                width: 1.1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => _showComplaintResponseDialog(c),
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
                                        Icons.build_rounded,
                                        color: AppTheme.accentColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textDark,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            subtitle,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    KosMateStatusChip.fromComplaintStatus(
                                      c.status,
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppTheme.accentColor,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (!_isLoading && _filteredComplaints.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: KosMatePaginationBar(
                    currentPage: paged.safePage,
                    totalPages: paged.totalPages,
                    totalItems: _filteredComplaints.length,
                    startIndex: paged.startIndex,
                    endIndex: paged.endIndex,
                    pageSize: _pageSize,
                    onPageChanged: (p) => setState(() => _page = p),
                    onPageSizeChanged: (s) => setState(() {
                      _pageSize = s;
                      _page = 1;
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AllPaymentsSheet extends StatefulWidget {
  final List<PaymentModel> payments;
  final VoidCallback onPaymentUpdated;
  final VoidCallback? onIssueInvoice;

  const _AllPaymentsSheet({
    required this.payments,
    required this.onPaymentUpdated,
    this.onIssueInvoice,
  });

  @override
  State<_AllPaymentsSheet> createState() => _AllPaymentsSheetState();
}

class _AllPaymentsSheetState extends State<_AllPaymentsSheet> {
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
