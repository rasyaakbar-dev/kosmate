import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/house_model.dart';
import '../../../models/user_model.dart';
import '../complaints/tenant_add_complaint_dialog.dart';
import '../complaints/tenant_complaint_detail_dialog.dart';
import 'house_rooms_picker_screen.dart';

class TenantRoomsTab extends StatefulWidget {
  final UserModel user;
  const TenantRoomsTab({super.key, required this.user});

  @override
  State<TenantRoomsTab> createState() => _TenantRoomsTabState();
}

class _TenantRoomsTabState extends State<TenantRoomsTab> {
  final _bookingService = sl.booking;
  final _houseService = sl.house;
  final _complaintService = sl.complaint;

  bool _isLoading = true;
  BookingModel? _activeBooking;
  BookingModel? _pendingBooking;
  List<ComplaintModel> _complaints = [];
  int _complaintFilter = 0; // 0 = All, 1 = Resolved

  // Houses for when tenant has no active room
  List<HouseModel> _houses = [];
  String _houseSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final bookings = await _bookingService.getBookingsByUser(
        widget.user.userId,
      );
      final active = bookings
          .where((b) => b.status == BookingStatus.approved)
          .firstOrNull;
      final pending = bookings
          .where((b) => b.status == BookingStatus.pending)
          .firstOrNull;

      List<ComplaintModel> complaints = [];
      if (active != null) {
        complaints = await _complaintService.getComplaintsByRoom(active.roomId);
      }

      List<HouseModel> houses = [];
      if (active == null) {
        houses = await _houseService.getAllHouses();
      }

      if (mounted) {
        setState(() {
          _activeBooking = active;
          _pendingBooking = pending;
          _complaints = complaints;
          _houses = houses;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCancelBooking(BookingModel booking) async {
    final eligibility = _bookingService.checkCancellationEligibility(booking);

    if (!eligibility.allowed) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.warningColor),
              SizedBox(width: 8),
              Text('Cancellation Policy'),
            ],
          ),
          content: Text(
            eligibility.reason ?? 'You cannot cancel your booking at this time according to house policy.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Room Booking?'),
        content: Text(
          'Are you sure you want to cancel your stay in Room ${booking.room?.roomNumber ?? ''}?\n\n'
          'Your room will be vacated and made available for other prospective tenants.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructiveColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _bookingService.cancelTenantBooking(booking: booking);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Your booking has been cancelled and room vacated.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadData();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
      }
    }
  }

  Future<void> _handleCancelPendingRequest(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Request?'),
        content: const Text(
          'Do you want to cancel your pending room booking request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructiveColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _bookingService.updateBookingStatus(
          bookingId: booking.bookingId,
          status: BookingStatus.cancelled,
          roomId: booking.roomId,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Booking request withdrawn.')),
        );
        _loadData();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // IF USER HAS AN APPROVED ACTIVE ROOM -> RENDER FIGMA "MY ROOM"
    if (_activeBooking != null && _activeBooking!.room != null) {
      return _buildMyRoomView(_activeBooking!);
    }

    // OTHERWISE -> RENDER SEARCH & HOUSE PICKER
    return _buildSearchAndPickHouseView();
  }

  // ===========================================================================
  // 1. MY ROOM VIEW (FIGMA figma/tenant/Room.png)
  // ===========================================================================
  Widget _buildMyRoomView(BookingModel booking) {
    final room = booking.room!;
    final house = room.house;
    final requestId = 'KM-RR-${booking.bookingId.toString().padLeft(4, '0')}';

    final filteredComplaints = _complaints.where((c) {
      if (_complaintFilter == 1) return c.status == ComplaintStatus.resolved;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBadgeBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.sensor_door_outlined,
                    color: AppTheme.accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${room.roomNumber}',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.foregroundColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${house?.houseName ?? "Boarding House"} • ${room.roomType}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Occupied',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Room information',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildInfoRow('Room type', room.roomType),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    'Monthly rent',
                    Formatters.formatCurrency(room.price),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    'Request date',
                    Formatters.formatDate(booking.requestDate),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow('Request ID', requestId),
                  const SizedBox(height: 10),
                  _buildInfoRow('Room ID', '#${room.roomId}'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Facilities',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildFacilitiesGrid(room.facilities ?? ''),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.borderColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'House rules',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    house?.description != null &&
                            house!.description!.trim().isNotEmpty
                        ? house.description!
                        : 'Quiet hours after 22:00. Keep shared areas clean. Guests must leave by 21:00.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Maintenance & Complaints',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foregroundColor,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add ticket'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    TenantAddComplaintDialog.show(
                      context,
                      userId: widget.user.userId,
                      roomId: room.roomId,
                      onSubmitted: _loadData,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _complaintFilter = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _complaintFilter == 0
                            ? AppTheme.accentColor
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'All complaints',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _complaintFilter == 0
                              ? Colors.white
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _complaintFilter = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _complaintFilter == 1
                            ? AppTheme.accentColor
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Resolved',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _complaintFilter == 1
                              ? Colors.white
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (filteredComplaints.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'No complaints registered for this room.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredComplaints.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = filteredComplaints[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: InkWell(
                      onTap: () => TenantComplaintDetailDialog.show(context, c),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.iconBadgeBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.build_outlined,
                              color: AppTheme.accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.foregroundColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  c.description,
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
                          KosMateStatusChip.fromComplaintStatus(c.status),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: AppTheme.textSubtle,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 36),

            Center(
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.exit_to_app_rounded,
                  color: AppTheme.destructiveColor,
                  size: 20,
                ),
                label: const Text(
                  'Cancel Booking / Vacate Room',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.destructiveColor,
                  ),
                ),
                onPressed: () => _handleCancelBooking(booking),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  side: const BorderSide(
                    color: AppTheme.destructiveColor,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Note: Cancellation is restricted in the 1st month & near month-end.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSubtle),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.foregroundColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFacilitiesGrid(String facilitiesStr) {
    final defaultFacilities = [
      {'title': 'Single bed', 'icon': Icons.bed_outlined},
      {'title': 'Study desk', 'icon': Icons.desk_outlined},
      {'title': 'Bathroom', 'icon': Icons.shower_outlined},
    ];

    return Row(
      children: defaultFacilities.map((f) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              children: [
                Icon(
                  f['icon'] as IconData,
                  color: AppTheme.accentColor,
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  f['title'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // 2. SEARCH & PICK HOUSE VIEW (WHEN USER HAS NO ROOM)
  // ===========================================================================
  Widget _buildSearchAndPickHouseView() {
    final filteredHouses = _houses.where((h) {
      final q = _houseSearchQuery.toLowerCase();
      return h.houseName.toLowerCase().contains(q) ||
          h.houseAddress.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_pendingBooking != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pending_actions_outlined,
                      color: AppTheme.warningColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Booking Request Pending',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.warningColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Room ${_pendingBooking!.room?.roomNumber ?? ""} • ${_pendingBooking!.room?.house?.houseName ?? "Boarding House"}\n'
                            'The owner is reviewing your request.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _handleCancelPendingRequest(_pendingBooking!),
                      child: const Text(
                        'Withdraw',
                        style: TextStyle(
                          color: AppTheme.destructiveColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              decoration: InputDecoration(
                hintText: 'Search boarding houses by name or address...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSubtle,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.textMuted,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.accentColor,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (val) =>
                  setState(() => _houseSearchQuery = val.trim()),
            ),
            const SizedBox(height: 18),

            const Text(
              'Boarding Houses',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 10),

            if (filteredHouses.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(
                      Icons.home_work_outlined,
                      size: 48,
                      color: AppTheme.borderMedium,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No boarding houses match your search.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredHouses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final house = filteredHouses[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppTheme.borderLight),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final booked = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HouseRoomsPickerScreen(
                              house: house,
                              user: widget.user,
                            ),
                          ),
                        );
                        if (booked == true) _loadData();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 64,
                                height: 64,
                                color: AppTheme.borderLight,
                                child:
                                    house.thumbnailUrl != null &&
                                        house.thumbnailUrl!.trim().isNotEmpty
                                    ? Image.network(
                                        house.thumbnailUrl!.trim(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.home_work_outlined,
                                          color: AppTheme.textSubtle,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.home_work_outlined,
                                        color: AppTheme.textSubtle,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    house.houseName,
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.foregroundColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    house.houseAddress,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMuted,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  const Row(
                                    children: [
                                      Text(
                                        'View Available Rooms',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.accentColor,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 14,
                                        color: AppTheme.accentColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
