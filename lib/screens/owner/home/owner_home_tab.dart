import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';
import '../complaints/owner_complaints_screen.dart';

class OwnerHomeTab extends StatefulWidget {
  final UserModel user;
  final Function(int) onNavigateToTab;

  const OwnerHomeTab({
    super.key,
    required this.user,
    required this.onNavigateToTab,
  });

  @override
  State<OwnerHomeTab> createState() => _OwnerHomeTabState();
}

class _OwnerHomeTabState extends State<OwnerHomeTab> {
  final _roomService = sl.room;
  final _houseService = sl.house;
  final _bookingService = sl.booking;
  final _paymentService = sl.payment;
  final _complaintService = sl.complaint;

  int _totalRooms = 0;
  int _availableRooms = 0;
  int _unpaidOverduePaymentsCount = 0;

  List<BookingModel> _recentBookings = [];
  List<PaymentModel> _recentPayments = [];
  List<ComplaintModel> _recentComplaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final houses = await _houseService.getHousesByOwner(widget.user.userId);
      final bookings = await _bookingService.getBookingsForOwner(
        widget.user.userId,
      );
      final payments = await _paymentService.getPaymentsForOwner(
        widget.user.userId,
      );
      final complaints = await _complaintService.getComplaintsForOwner(
        widget.user.userId,
      );

      int total = 0;
      int available = 0;

      for (final h in houses) {
        final rooms = await _roomService.getRooms(houseId: h.houseId);
        total += rooms.length;
        available += rooms
            .where((r) => r.status == RoomStatus.available)
            .length;
      }

      final unpaidOverdue = payments
          .where(
            (p) =>
                p.status == PaymentStatus.pending ||
                p.status == PaymentStatus.overdue,
          )
          .length;

      if (mounted) {
        setState(() {
          _totalRooms = total;
          _availableRooms = available;
          _unpaidOverduePaymentsCount = unpaidOverdue;
          _recentBookings = bookings;
          _recentPayments = payments;
          _recentComplaints = complaints;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openComplaintsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerComplaintsScreen(owner: widget.user),
      ),
    ).then((_) {
      if (mounted) _loadDashboardData();
    });
  }

  void _showBookingRequestsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Booking Requests / Assign Renter',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _recentBookings.isEmpty
                    ? const Center(child: Text('No pending booking requests.'))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: _recentBookings.length,
                        itemBuilder: (context, idx) {
                          final b = _recentBookings[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(
                                'Room ${b.room?.roomNumber ?? b.roomId}',
                              ),
                              subtitle: Text(
                                'Tenant: ${b.user?.name ?? "User"}\nMove-in: ${Formatters.formatDate(b.requestDate)}',
                              ),
                              trailing: ElevatedButton(
                                onPressed: b.status == BookingStatus.pending
                                    ? () async {
                                        await _bookingService
                                            .updateBookingStatus(
                                              bookingId: b.bookingId,
                                              status: BookingStatus.approved,
                                              roomId: b.roomId,
                                            );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        _loadDashboardData();
                                      }
                                    : null,
                                child: Text(
                                  b.status == BookingStatus.pending
                                      ? 'Approve'
                                      : b.status.displayName,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekdayName = weekdays[now.weekday - 1];
    final dateStr = '$weekdayName, ${Formatters.formatDate(now)}';
    final ownerName = widget.user.name.trim().isNotEmpty
        ? widget.user.name.trim()
        : 'Owner';

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning, $ownerName',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _buildStatCard(
                  label: 'Rooms',
                  count: '$_availableRooms',
                  subtext: 'available of $_totalRooms',
                  icon: Icons.meeting_room_outlined,
                  bgColor: AppTheme.primaryLight,
                  borderColor: AppTheme.borderLight,
                  textColor: AppTheme.primaryColor,
                  onTap: () => widget.onNavigateToTab(1),
                ),
                const SizedBox(width: 14),
                _buildStatCard(
                  label: 'Payments',
                  count: '$_unpaidOverduePaymentsCount',
                  subtext: 'bills need attention',
                  icon: Icons.receipt_long_outlined,
                  bgColor: AppTheme.warningLight,
                  borderColor: AppTheme.warningLight,
                  textColor: AppTheme.primaryColor,
                  onTap: () => widget.onNavigateToTab(2),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Quick actions',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                _buildQuickActionTile(
                  icon: Icons.meeting_room_outlined,
                  label: 'Rooms',
                  onTap: () => widget.onNavigateToTab(1),
                ),
                const SizedBox(width: 10),
                _buildQuickActionTile(
                  icon: Icons.assignment_ind_outlined,
                  label: 'Bookings',
                  onTap: _showBookingRequestsModal,
                ),
                const SizedBox(width: 10),
                _buildQuickActionTile(
                  icon: Icons.build_circle_outlined,
                  label: 'Complaints',
                  onTap: _openComplaintsScreen,
                ),
                const SizedBox(width: 10),
                _buildQuickActionTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Payments',
                  onTap: () => widget.onNavigateToTab(2),
                ),
              ],
            ),
            const SizedBox(height: 26),

            const Text(
              'Recent information',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 12),

            ..._buildRecentActivitiesList(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecentActivitiesList() {
    final List<Widget> items = [];

    // Prioritize unresolved & in-progress complaints at the very top!
    final activeComplaints = _recentComplaints
        .where((c) => c.status != ComplaintStatus.resolved)
        .toList();
    final otherComplaints = _recentComplaints
        .where((c) => c.status == ComplaintStatus.resolved)
        .toList();

    for (final c in activeComplaints) {
      items.add(
        _buildRecentCard(
          icon: Icons.build_circle_outlined,
          title: 'Complaint: ${c.title}',
          subtitle: '${c.description} • Room ${c.room?.roomNumber ?? c.roomId}',
          trailingBadge: c.status.displayName,
          badgeColor: c.status == ComplaintStatus.pending
              ? AppTheme.destructiveLight
              : AppTheme.warningLight,
          badgeTextColor: c.status == ComplaintStatus.pending
              ? AppTheme.destructiveColor
              : AppTheme.warningColor,
          trailingText: Formatters.formatDate(c.date),
          onTap: _openComplaintsScreen,
        ),
      );
    }

    // Pending/overdue payments next
    final unpaidPayments = _recentPayments
        .where(
          (p) =>
              p.status == PaymentStatus.pending ||
              p.status == PaymentStatus.overdue,
        )
        .toList();
    for (final p in unpaidPayments) {
      items.add(
        _buildRecentCard(
          icon: Icons.receipt_long_outlined,
          title:
              'Payment ${p.status == PaymentStatus.overdue ? "Overdue" : "Pending"}: ${Formatters.formatCurrency(p.amount)}',
          subtitle:
              '${p.user?.name ?? "Tenant"} • Room ${p.room?.roomNumber ?? p.roomId}',
          trailingBadge: p.status.displayName,
          badgeColor: p.status == PaymentStatus.overdue
              ? AppTheme.destructiveLight
              : AppTheme.warningLight,
          badgeTextColor: p.status == PaymentStatus.overdue
              ? AppTheme.destructiveColor
              : AppTheme.warningColor,
          trailingText: Formatters.formatDate(p.dueDate),
          onTap: () => widget.onNavigateToTab(2),
        ),
      );
    }

    // Pending booking requests
    final pendingBookings = _recentBookings
        .where((b) => b.status == BookingStatus.pending)
        .toList();
    for (final b in pendingBookings) {
      items.add(
        _buildRecentCard(
          icon: Icons.assignment_ind_outlined,
          title: 'Booking request',
          subtitle:
              '${b.user?.name ?? "User"} • Room ${b.room?.roomNumber ?? b.roomId}',
          trailingBadge: b.status.displayName,
          badgeColor: AppTheme.primaryLight,
          badgeTextColor: AppTheme.accentColor,
          trailingText: Formatters.formatDate(b.requestDate),
          onTap: _showBookingRequestsModal,
        ),
      );
    }

    // Paid payments and resolved complaints if we have room
    final paidPayments = _recentPayments
        .where((p) => p.status == PaymentStatus.paid)
        .toList();
    for (final p in paidPayments) {
      items.add(
        _buildRecentCard(
          icon: Icons.check_circle_outline,
          title: 'Payment received: ${Formatters.formatCurrency(p.amount)}',
          subtitle:
              '${p.user?.name ?? "Tenant"} • Room ${p.room?.roomNumber ?? p.roomId}',
          trailingBadge: p.status.displayName,
          badgeColor: AppTheme.successLight,
          badgeTextColor: AppTheme.successColor,
          trailingText: Formatters.formatDate(p.paidDate ?? p.dueDate),
          onTap: () => widget.onNavigateToTab(2),
        ),
      );
    }

    for (final c in otherComplaints) {
      items.add(
        _buildRecentCard(
          icon: Icons.task_alt_outlined,
          title: 'Complaint resolved: ${c.title}',
          subtitle: '${c.description} • Room ${c.room?.roomNumber ?? c.roomId}',
          trailingBadge: c.status.displayName,
          badgeColor: AppTheme.successLight,
          badgeTextColor: AppTheme.successColor,
          trailingText: Formatters.formatDate(c.date),
          onTap: _openComplaintsScreen,
        ),
      );
    }

    if (items.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'No recent activities yet.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ),
      ];
    }

    // Strict limit of 5 items max and NO "VIEW ALL"
    final limitedItems = items.take(5).toList();
    return limitedItems
        .map(
          (w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w),
        )
        .toList();
  }

  Widget _buildStatCard({
    required String label,
    required String count,
    String? subtext,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(icon, color: AppTheme.accentColor, size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  count,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: textColor ?? AppTheme.primaryColor,
                  ),
                ),
                if (subtext != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtext,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.accentColor, size: 24),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? trailingBadge,
    Color? badgeColor,
    Color? badgeTextColor,
    required String trailingText,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.iconBadgeBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (trailingBadge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor ?? AppTheme.destructiveLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trailingBadge,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeTextColor ?? AppTheme.destructiveColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    trailingText,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
