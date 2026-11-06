import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../core/widgets/kosmate_components.dart';
import '../../models/user_model.dart';
import '../../models/house_model.dart';
import '../../models/room_model.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/complaint_model.dart';
import '../../services/house_service.dart';
import '../../services/room_service.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';
import '../../services/complaint_service.dart';
import '../shared/profile_screen.dart';
import '../shared/house_form_screen.dart';
import '../shared/house_detail_screen.dart';

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
      _OwnerHomeDashboard(
        user: widget.user,
        onNavigateToTab: _navigateToTab,
      ),
      _OwnerPropertiesTab(user: widget.user),
      _OwnerPaymentsTab(user: widget.user),
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
        appBarTitle = 'Payments';
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
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
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
              selectedIcon: Icon(Icons.sensor_door, color: AppTheme.primaryColor),
              label: 'Rooms',
            ),
            NavigationDestination(
              icon: Icon(Icons.mail_outline_rounded),
              selectedIcon: Icon(Icons.mail, color: AppTheme.primaryColor),
              label: 'Payments',
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
  final _roomService = RoomService();
  final _houseService = HouseService();
  final _bookingService = BookingService();
  final _paymentService = PaymentService();
  final _complaintService = ComplaintService();

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
      final bookings = await _bookingService.getBookingsForOwner(widget.user.userId);
      final payments = await _paymentService.getPaymentsForOwner(widget.user.userId);
      final complaints = await _complaintService.getComplaintsForOwner(widget.user.userId);

      int total = 0;
      int occupied = 0;
      int available = 0;

      for (final h in houses) {
        final rooms = await _roomService.getRooms(houseId: h.houseId);
        total += rooms.length;
        occupied += rooms.where((r) => r.status == RoomStatus.occupied).length;
        available += rooms.where((r) => r.status == RoomStatus.available).length;
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

  void _showAddRoomDialog() {
    if (_houses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a boarding house first.')),
      );
      widget.onNavigateToTab(1);
      return;
    }

    final numberCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final facilitiesCtrl = TextEditingController();
    int selectedHouseId = _houses.first.houseId;
    RoomStatus selectedStatus = RoomStatus.available;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Room'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedHouseId,
                  decoration: const InputDecoration(labelText: 'Boarding House'),
                  items: _houses.map((h) {
                    return DropdownMenuItem(value: h.houseId, child: Text(h.houseName));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedHouseId = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numberCtrl,
                  decoration: const InputDecoration(labelText: 'Room Number (e.g. A-01)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(labelText: 'Room Type (e.g. Deluxe/Single)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monthly Price (IDR)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: facilitiesCtrl,
                  decoration: const InputDecoration(labelText: 'Facilities'),
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
              onPressed: () async {
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                if (numberCtrl.text.trim().isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _roomService.createRoom(
                    RoomModel(
                      roomId: 0,
                      houseId: selectedHouseId,
                      roomNumber: numberCtrl.text.trim(),
                      roomType: typeCtrl.text.trim(),
                      price: price,
                      facilities: facilitiesCtrl.text.trim(),
                      status: selectedStatus,
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) _loadDashboardData();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save Room'),
            ),
          ],
        ),
      ),
    );
  }

  void _showComplaintsModal() {
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
                'Tenant Complaints',
                style: TextStyle(fontFamily: 'Roboto', fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _recentComplaints.isEmpty
                    ? const KosMateEmptyState(
                        icon: Icons.feedback_outlined,
                        title: 'No complaints yet',
                        subtitle: 'Tenant complaints will appear here.',
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: _recentComplaints.length,
                        itemBuilder: (context, idx) {
                          final c = _recentComplaints[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${c.description}\nPriority: ${c.priority.displayName}${c.response != null ? "\nResponse: ${c.response}" : ""}',
                              ),
                              trailing: Chip(
                                label: Text(c.status.displayName),
                                backgroundColor: c.status == ComplaintStatus.resolved
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : c.status == ComplaintStatus.inProgress
                                        ? Colors.blue.withValues(alpha: 0.15)
                                        : Colors.amber.withValues(alpha: 0.15),
                              ),
                              onTap: () => _showComplaintResponseDialog(c),
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

  void _showComplaintResponseDialog(ComplaintModel complaint) {
    final responseCtrl = TextEditingController(text: complaint.response ?? '');
    ComplaintStatus selectedStatus = complaint.status == ComplaintStatus.pending
        ? ComplaintStatus.inProgress
        : complaint.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Respond to: ${complaint.title}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tenant Description:\n${complaint.description}',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ComplaintStatus>(
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
                    DropdownMenuItem(
                      value: ComplaintStatus.rejected,
                      child: Text('Rejected'),
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
                    labelText: 'Response / Action taken',
                    hintText: 'e.g., Plumber has been contacted and scheduled.',
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
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _complaintService.respondToComplaint(
                    complaintId: complaint.complaintId,
                    responseText: responseCtrl.text.trim(),
                    status: selectedStatus,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadDashboardData();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Complaint updated successfully!')),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
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
                style: TextStyle(fontFamily: 'Roboto', fontSize: 20, fontWeight: FontWeight.bold),
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
                              title: Text('Room ${b.room?.roomNumber ?? b.roomId}'),
                              subtitle: Text('Tenant: ${b.user?.name ?? "User"}\nMove-in: ${Formatters.formatDate(b.requestDate)}'),
                              trailing: ElevatedButton(
                                onPressed: b.status == BookingStatus.pending
                                    ? () async {
                                        await _bookingService.updateBookingStatus(
                                          bookingId: b.bookingId,
                                          status: BookingStatus.approved,
                                          roomId: b.roomId,
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        _loadDashboardData();
                                      }
                                    : null,
                                child: Text(b.status == BookingStatus.pending ? 'Approve' : b.status.displayName),
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
      'Sunday'
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
                  onTap: _showAddRoomDialog,
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
                  onTap: _showComplaintsModal,
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
                GestureDetector(
                  onTap: () => widget.onNavigateToTab(2),
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
                trailingText: Formatters.formatDate(_recentPayments.first.paidDate ?? _recentPayments.first.dueDate),
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
                trailingText: Formatters.formatDate(_recentComplaints.first.date),
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
                trailingText: Formatters.formatDate(_recentBookings.first.requestDate),
              ),
            ] else if (_recentPayments.isEmpty && _recentComplaints.isEmpty) ...[
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
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
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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

// -----------------------------------------------------------------------------
// TAB 1: PROPERTIES (HOUSES & ROOMS)
// -----------------------------------------------------------------------------
class _OwnerPropertiesTab extends StatefulWidget {
  final UserModel user;
  const _OwnerPropertiesTab({required this.user});

  @override
  State<_OwnerPropertiesTab> createState() => _OwnerPropertiesTabState();
}

class _OwnerPropertiesTabState extends State<_OwnerPropertiesTab> {
  final _houseService = HouseService();
  final _roomService = RoomService();

  late Future<List<HouseModel>> _housesFuture;

  @override
  void initState() {
    super.initState();
    _loadHouses();
  }

  void _loadHouses() {
    setState(() {
      _housesFuture = _houseService.getHousesByOwner(widget.user.userId);
    });
  }

  Future<void> _openAddHouseScreen() async {
    final created = await Navigator.push<HouseModel>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseFormScreen(ownerId: widget.user.userId),
      ),
    );
    if (created != null && mounted) {
      _loadHouses();
    }
  }

  Future<void> _openHouseDetails(HouseModel house) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseDetailScreen(
          house: house,
          currentUser: widget.user,
        ),
      ),
    );
    if (changed == true && mounted) {
      _loadHouses();
    }
  }

  Future<void> _openEditHouse(HouseModel house) async {
    final updated = await Navigator.push<HouseModel>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseFormScreen(
          house: house,
          ownerId: widget.user.userId,
        ),
      ),
    );
    if (updated != null && mounted) {
      _loadHouses();
    }
  }

  Future<void> _confirmDeleteHouse(HouseModel house) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Boarding House'),
        content: Text(
          'Are you sure you want to delete "${house.houseName}"?\n\n'
          'All associated rooms and records will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB33A3A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _houseService.deleteHouse(house.houseId);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Boarding house deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadHouses();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Boarding Houses & Rooms',
                style: TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add House'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _openAddHouseScreen,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadHouses(),
            child: FutureBuilder<List<HouseModel>>(
              future: _housesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final houses = snapshot.data ?? [];
                if (houses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.home_work_outlined, size: 60, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          const Text(
                            'No boarding houses listed yet.',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Click "Add House" above to list your first boarding house.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: houses.length,
                  itemBuilder: (context, index) {
                    final house = houses[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openHouseDetails(house),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      color: const Color(0xFFE2E8F0),
                                      child: house.thumbnailUrl != null &&
                                              house.thumbnailUrl!.trim().isNotEmpty
                                          ? Image.network(
                                              house.thumbnailUrl!.trim(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => const Icon(
                                                Icons.home_work_outlined,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.home_work_outlined,
                                              color: Color(0xFF94A3B8),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          house.houseName,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.foregroundColor,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          house.houseAddress,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
                                    onSelected: (action) {
                                      if (action == 'details') {
                                        _openHouseDetails(house);
                                      } else if (action == 'edit') {
                                        _openEditHouse(house);
                                      } else if (action == 'delete') {
                                        _confirmDeleteHouse(house);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'details',
                                        child: Row(
                                          children: [
                                            Icon(Icons.visibility_outlined, size: 18, color: AppTheme.accentColor),
                                            SizedBox(width: 8),
                                            Text('View Details & Rooms'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                                            SizedBox(width: 8),
                                            Text('Edit House'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 18, color: Color(0xFFB33A3A)),
                                            SizedBox(width: 8),
                                            Text('Delete House', style: TextStyle(color: Color(0xFFB33A3A))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              FutureBuilder<List<RoomModel>>(
                                future: _roomService.getRooms(houseId: house.houseId),
                                builder: (context, roomSnap) {
                                  if (roomSnap.connectionState == ConnectionState.waiting) {
                                    return const Center(child: LinearProgressIndicator());
                                  }
                                  final rooms = roomSnap.data ?? [];
                                  if (rooms.isEmpty) {
                                    return const Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
                                        SizedBox(width: 6),
                                        Text(
                                          'No rooms added to this house yet.',
                                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    );
                                  }

                                  final availableCount = rooms.where((r) => r.status == RoomStatus.available).length;
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${rooms.length} Rooms total ($availableCount available)',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                      const Text(
                                        'Manage >',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.accentColor,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: PAYMENTS MANAGEMENT
// -----------------------------------------------------------------------------
class _OwnerPaymentsTab extends StatefulWidget {
  final UserModel user;
  const _OwnerPaymentsTab({required this.user});

  @override
  State<_OwnerPaymentsTab> createState() => _OwnerPaymentsTabState();
}

class _OwnerPaymentsTabState extends State<_OwnerPaymentsTab> {
  final _paymentService = PaymentService();
  late Future<List<PaymentModel>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() {
    setState(() {
      _paymentsFuture = _paymentService.getPaymentsForOwner(widget.user.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _loadPayments(),
      child: FutureBuilder<List<PaymentModel>>(
        future: _paymentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('No payment invoices registered.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final p = list[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            Formatters.formatCurrency(p.amount),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Chip(label: Text(p.status.displayName)),
                        ],
                      ),
                      Text('Tenant: ${p.user?.name ?? "User"} • Room: ${p.room?.roomNumber ?? p.roomId}'),
                      Text('Due: ${Formatters.formatDate(p.dueDate)}'),
                      if (p.orderId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Midtrans Order: ${p.orderId}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.accentColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                      if (p.receiptUrl != null) ...[
                        const SizedBox(height: 8),
                        Text('Receipt: ${p.receiptUrl}', style: const TextStyle(color: Colors.blue)),
                      ],
                      if (p.status == PaymentStatus.pending) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Confirm as Paid'),
                            onPressed: () async {
                              await _paymentService.updatePaymentStatus(
                                paymentId: p.paymentId,
                                status: PaymentStatus.paid,
                              );
                              _loadPayments();
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


