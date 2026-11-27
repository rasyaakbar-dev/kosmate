import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';
import 'widgets/owner_complaints_sheet.dart';
import 'widgets/owner_payments_sheet.dart';
import 'widgets/tenant_inspector_sheet.dart';

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

      final payments = await _paymentService.getPaymentsForOwner(ownerId);
      _allPayments = payments;
      final Map<int, List<PaymentModel>> paymentMap = {};
      for (final p in payments) {
        paymentMap.putIfAbsent(p.userId, () => []).add(p);
      }
      _paymentsByTenant = paymentMap;

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
            KosMateCancelButton(
              isOutlined: false,
              onPressed: () => Navigator.pop(ctx),
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
    ).whenComplete(amountController.dispose);
  }

  void _openComplaintsManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OwnerComplaintsSheet(ownerId: widget.user.userId),
    ).then((_) {
      if (mounted) _loadManagementData();
    });
  }

  void _openPaymentsManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OwnerPaymentsSheet(
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
      builder: (ctx) => TenantInspectorSheet(
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

            if (_pendingBookings.isNotEmpty) ...[
              _buildPendingBookingsSection(),
              const SizedBox(height: 24),
            ],

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
