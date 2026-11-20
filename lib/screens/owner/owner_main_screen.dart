import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../models/user_model.dart';
import '../../models/house_model.dart';
import '../../models/room_model.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/complaint_model.dart';
import '../houses/house_form_screen.dart';
import '../shared/profile_screen.dart';
import 'rooms/owner_rooms_tab.dart';
import 'rooms/room_form_screen.dart';
import 'payments/owner_payments_tab.dart' show OwnerManagementHubTab;
import 'complaints/owner_complaints_screen.dart';

class OwnerMainScreen extends StatefulWidget {
  final UserModel user;

  const OwnerMainScreen({super.key, required this.user});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _OwnerHomeDashboard(user: widget.user, onNavigateToTab: _navigateToTab),
      OwnerRoomsTab(currentUser: widget.user),
      OwnerManagementHubTab(user: widget.user),
      ProfileScreen(user: widget.user),
    ];

    String appBarTitle;
    IconData actionIcon;
    switch (_currentIndex) {
      case 1:
        appBarTitle = 'Rooms';
        actionIcon = Icons.help_outline_rounded;
        break;
      case 2:
        appBarTitle = 'Management';
        actionIcon = Icons.help_outline_rounded;
        break;
      case 3:
        appBarTitle = 'Profile';
        actionIcon = Icons.settings_outlined;
        break;
      default:
        appBarTitle = 'KosMate';
        actionIcon = Icons.help_outline_rounded;
    }

    return Scaffold(
      appBar: KosMateAppBar(title: appBarTitle, actionIcon: actionIcon),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFEBF3FA),
          elevation: 0,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppTheme.primaryColor),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.sensor_door_outlined),
              selectedIcon: Icon(
                Icons.sensor_door,
                color: AppTheme.primaryColor,
              ),
              label: 'Rooms',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(
                Icons.assignment,
                color: AppTheme.primaryColor,
              ),
              label: 'Management',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.primaryColor),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 0: OWNER HOME DASHBOARD (Matches Figma Owner_Main.png)
// -----------------------------------------------------------------------------
class _OwnerHomeDashboard extends StatefulWidget {
  final UserModel user;
  final Function(int) onNavigateToTab;

  const _OwnerHomeDashboard({
    required this.user,
    required this.onNavigateToTab,
  });

  @override
  State<_OwnerHomeDashboard> createState() => _OwnerHomeDashboardState();
}

class _OwnerHomeDashboardState extends State<_OwnerHomeDashboard> {
  final _roomService = sl.room;
  final _houseService = sl.house;
  final _bookingService = sl.booking;
  final _paymentService = sl.payment;
  final _complaintService = sl.complaint;

  int _totalRooms = 0;
  int _occupiedRooms = 0;
  int _availableRooms = 0;

  List<HouseModel> _houses = [];
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
      int occupied = 0;
      int available = 0;

      for (final h in houses) {
        final rooms = await _roomService.getRooms(houseId: h.houseId);
        total += rooms.length;
        occupied += rooms.where((r) => r.status == RoomStatus.occupied).length;
        available += rooms
            .where((r) => r.status == RoomStatus.available)
            .length;
      }

      if (mounted) {
        setState(() {
          _houses = houses;
          _totalRooms = total;
          _occupiedRooms = occupied;
          _availableRooms = available;
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

  Future<void> _openAddRoomScreen() async {
    if (_houses.isEmpty) {
      final createdHouse = await Navigator.push<HouseModel>(
        context,
        MaterialPageRoute(
          builder: (_) => HouseFormScreen(ownerId: widget.user.userId),
        ),
      );
      if (createdHouse != null && mounted) {
        await _loadDashboardData();
        if (!mounted) return;
        final wantAddRoom = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('House "${createdHouse.houseName}" Created!'),
            content: const Text(
              'Would you like to add the first room to this boarding house now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Later'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add Room Now'),
              ),
            ],
          ),
        );
        if (wantAddRoom == true && mounted) {
          _openAddRoomScreen();
        }
      }
      return;
    }

    final created = await Navigator.push<RoomModel>(
      context,
      MaterialPageRoute(
        builder: (_) => RoomFormScreen(
          ownerId: widget.user.userId,
          houseId: _houses.firstOrNull?.houseId,
        ),
      ),
    );
    if (created != null && mounted) {
      _loadDashboardData();
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
            // Greeting Header
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
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),

            // 3 Stat Cards (Total rooms, Occupied, Available)
            Row(
              children: [
                _buildStatCard(
                  label: 'Total rooms',
                  count: '$_totalRooms',
                  icon: Icons.sensor_door_outlined,
                  bgColor: const Color(0xFFEBF3FA),
                  borderColor: const Color(0xFFD0E1F3),
                ),
                const SizedBox(width: 10),
                _buildStatCard(
                  label: 'Occupied',
                  count: '$_occupiedRooms',
                  icon: Icons.group_outlined,
                  bgColor: const Color(0xFFFEF9E7),
                  borderColor: const Color(0xFFF9E8B5),
                ),
                const SizedBox(width: 10),
                _buildStatCard(
                  label: 'Available',
                  count: '$_availableRooms',
                  icon: Icons.meeting_room_outlined,
                  bgColor: const Color(0xFFE6F4EA),
                  borderColor: const Color(0xFFC7EBD1),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions Heading
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

            // 3 Quick Action Tiles
            Row(
              children: [
                _buildQuickActionTile(
                  icon: Icons.add,
                  label: 'Add room',
                  onTap: _openAddRoomScreen,
                ),
                const SizedBox(width: 12),
                _buildQuickActionTile(
                  icon: Icons.person_add_outlined,
                  label: 'Assign renter',
                  onTap: _showBookingRequestsModal,
                ),
                const SizedBox(width: 12),
                _buildQuickActionTile(
                  icon: Icons.feedback_outlined,
                  label: 'Complaints',
                  onTap: _openComplaintsScreen,
                ),
              ],
            ),
            const SizedBox(height: 26),

            // Recent Information Heading with "View all"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent information',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foregroundColor,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateToTab(2),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recent Information List Cards
            if (_recentPayments.isNotEmpty) ...[
              _buildRecentCard(
                icon: Icons.receipt_long_outlined,
                title: 'Payment received',
                subtitle:
                    '${_recentPayments.first.user?.name ?? "Tenant"} • Room ${_recentPayments.first.room?.roomNumber ?? _recentPayments.first.roomId}',
                trailingText: Formatters.formatDate(
                  _recentPayments.first.paidDate ??
                      _recentPayments.first.dueDate,
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (_recentComplaints.isNotEmpty) ...[
              _buildRecentCard(
                icon: Icons.build_outlined,
                title: 'Complaint: ${_recentComplaints.first.title}',
                subtitle:
                    '${_recentComplaints.first.description} • Room ${_recentComplaints.first.room?.roomNumber ?? _recentComplaints.first.roomId}',
                trailingBadge: _recentComplaints.first.status.displayName,
                trailingText: Formatters.formatDate(
                  _recentComplaints.first.date,
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (_recentBookings.isNotEmpty) ...[
              _buildRecentCard(
                icon: Icons.person_outline,
                title: 'Booking request',
                subtitle:
                    '${_recentBookings.first.user?.name ?? "User"} • Room ${_recentBookings.first.room?.roomNumber ?? _recentBookings.first.roomId}',
                trailingBadge: _recentBookings.first.status.displayName,
                trailingText: Formatters.formatDate(
                  _recentBookings.first.requestDate,
                ),
              ),
            ] else if (_recentPayments.isEmpty &&
                _recentComplaints.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No recent activities yet.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String count,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
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
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: AppTheme.accentColor, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              count,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
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
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.accentColor, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
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
    required String trailingText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foregroundColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (trailingBadge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trailingBadge,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC81E1E),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            trailingText,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
