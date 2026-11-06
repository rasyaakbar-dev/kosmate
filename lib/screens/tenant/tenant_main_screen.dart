import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../core/widgets/kosmate_components.dart';
import '../../models/user_model.dart';
import '../../models/room_model.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/complaint_model.dart';
import '../../services/room_service.dart';
import '../../services/booking_service.dart';
import '../../services/payment_service.dart';
import '../../services/complaint_service.dart';
import '../shared/profile_screen.dart';
import 'widgets/midtrans_payment_sheet.dart';

class TenantMainScreen extends StatefulWidget {
  final UserModel user;

  const TenantMainScreen({super.key, required this.user});

  @override
  State<TenantMainScreen> createState() => _TenantMainScreenState();
}

class _TenantMainScreenState extends State<TenantMainScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _TenantHomeDashboard(user: widget.user, onNavigateToTab: _navigateToTab),
      _TenantRoomsTab(user: widget.user),
      _TenantPaymentsTab(user: widget.user),
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
              label: 'Room',
            ),
            NavigationDestination(
              icon: Icon(Icons.mail_outline_rounded),
              selectedIcon: Icon(Icons.mail, color: AppTheme.primaryColor),
              label: 'Payment',
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
// TAB 0: HOME DASHBOARD (Matches Figma Tenant_Main.png)
// -----------------------------------------------------------------------------
class _TenantHomeDashboard extends StatefulWidget {
  final UserModel user;
  final Function(int) onNavigateToTab;

  const _TenantHomeDashboard({
    required this.user,
    required this.onNavigateToTab,
  });

  @override
  State<_TenantHomeDashboard> createState() => _TenantHomeDashboardState();
}

class _TenantHomeDashboardState extends State<_TenantHomeDashboard> {
  final _bookingService = BookingService();
  final _paymentService = PaymentService();
  final _complaintService = ComplaintService();

  BookingModel? _activeBooking;
  PaymentModel? _latestPayment;
  ComplaintModel? _latestComplaint;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final bookings = await _bookingService.getBookingsByUser(
        widget.user.userId,
      );
      final payments = await _paymentService.getPaymentsByUser(
        widget.user.userId,
      );
      final complaints = await _complaintService.getComplaintsByUser(
        widget.user.userId,
      );

      if (mounted) {
        setState(() {
          _activeBooking = bookings.isNotEmpty ? bookings.first : null;
          _latestPayment = payments.isNotEmpty ? payments.first : null;
          _latestComplaint = complaints.isNotEmpty ? complaints.first : null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNewComplaintDialog() {
    if (_activeBooking == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Active Room Booking'),
          content: const Text(
            'You do not have an approved room booking yet. Complaints can only be submitted once your room booking request has been approved by the owner.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final descController = TextEditingController();
    ComplaintCategory selectedCategory = ComplaintCategory.maintenance;
    ComplaintPriority selectedPriority = ComplaintPriority.medium;

    final roomId = _activeBooking!.roomId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Submit Complaint (Room ${_activeBooking?.room?.roomNumber ?? roomId})',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ComplaintCategory>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ComplaintCategory.values.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c.displayName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedCategory = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ComplaintPriority>(
                  initialValue: selectedPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ComplaintPriority.values.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(p.displayName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedPriority = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Water leak',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
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
                if (titleController.text.trim().isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _complaintService.createComplaint(
                    userId: widget.user.userId,
                    roomId: roomId,
                    category: selectedCategory,
                    title: titleController.text,
                    description: descController.text,
                    priority: selectedPriority,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadDashboardData();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Complaint submitted successfully!'),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasActiveRoom =
        _activeBooking != null && _activeBooking?.room != null;
    final roomNumber = hasActiveRoom
        ? _activeBooking!.room!.roomNumber
        : 'None';
    final houseName = hasActiveRoom
        ? (_activeBooking!.room!.house?.houseName ?? 'Boarding House')
        : 'Explore available rooms';
    final paymentStatus = _latestPayment != null
        ? _latestPayment!.status.displayName
        : 'No bills';
    final greetingName = widget.user.name.trim().isNotEmpty
        ? widget.user.name.trim()
        : 'User';

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
              'Hello, $greetingName!',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasActiveRoom
                  ? 'Room $roomNumber • $houseName'
                  : 'No active room • $houseName',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),

            // Top Stat Cards (Room & Payment)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF3FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD0E1F3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Room',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                color: Color(0xFF475569),
                              ),
                            ),
                            Icon(
                              Icons.sensor_door_outlined,
                              color: AppTheme.accentColor,
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          roomNumber,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9E7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF9E8B5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Payment',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                color: Color(0xFF475569),
                              ),
                            ),
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppTheme.accentColor,
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          paymentStatus,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
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

            // 4 Action Tiles Grid
            Row(
              children: [
                _buildActionTile(
                  icon: Icons.bed_outlined,
                  label: 'My room',
                  onTap: () => widget.onNavigateToTab(1),
                ),
                const SizedBox(width: 10),
                _buildActionTile(
                  icon: Icons.mail_outline_rounded,
                  label: 'Payment',
                  onTap: () => widget.onNavigateToTab(2),
                ),
                const SizedBox(width: 10),
                _buildActionTile(
                  icon: Icons.feedback_outlined,
                  label: 'Complaint',
                  onTap: _showNewComplaintDialog,
                ),
                const SizedBox(width: 10),
                _buildActionTile(
                  icon: Icons.search_rounded,
                  label: 'Find Room',
                  onTap: () => widget.onNavigateToTab(1),
                ),
              ],
            ),
            const SizedBox(height: 26),

            // Recent Information Heading
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

            // Recent Information Cards
            if (_latestPayment != null) ...[
              Container(
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
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Latest Invoice',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.foregroundColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${Formatters.formatCurrency(_latestPayment!.amount)} • Due: ${Formatters.formatDate(_latestPayment!.dueDate)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _latestPayment!.status == PaymentStatus.paid
                            ? const Color(0xFFE6F4EA)
                            : const Color(0xFFFEF3D6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _latestPayment!.status.displayName,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _latestPayment!.status == PaymentStatus.paid
                              ? const Color(0xFF137333)
                              : Colors.orange[800],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_latestComplaint != null) ...[
              Container(
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
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _latestComplaint!.title,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.foregroundColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _latestComplaint!.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(label: Text(_latestComplaint!.status.displayName)),
                  ],
                ),
              ),
            ] else if (_latestPayment == null) ...[
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

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
                  fontSize: 12,
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
}

// -----------------------------------------------------------------------------
// TAB 1: ROOMS CATALOG
// -----------------------------------------------------------------------------
class _TenantRoomsTab extends StatefulWidget {
  final UserModel user;
  const _TenantRoomsTab({required this.user});

  @override
  State<_TenantRoomsTab> createState() => _TenantRoomsTabState();
}

class _TenantRoomsTabState extends State<_TenantRoomsTab> {
  final _roomService = RoomService();
  final _bookingService = BookingService();

  late Future<List<RoomModel>> _roomsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  void _loadRooms() {
    setState(() {
      _roomsFuture = _roomService.getRooms(status: RoomStatus.available);
    });
  }

  void _showBookingDialog(RoomModel room) {
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Book Room ${room.roomNumber}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.house?.houseName ?? 'Boarding House',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${Formatters.formatCurrency(room.price)} / month',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Desired Move-in Date:'),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(Formatters.formatDate(selectedDate)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes for Owner (optional)',
                    hintText: 'e.g. Bringing motorcycle...',
                  ),
                  maxLines: 2,
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
                  await _bookingService.createBooking(
                    userId: widget.user.userId,
                    roomId: room.roomId,
                    requestDate: selectedDate,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Booking request sent successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: const Text('Submit Booking'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search room number or type...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadRooms(),
            child: FutureBuilder<List<RoomModel>>(
              future: _roomsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rooms = snapshot.data ?? [];
                final filtered = rooms.where((r) {
                  return r.roomNumber.toLowerCase().contains(_searchQuery) ||
                      r.roomType.toLowerCase().contains(_searchQuery) ||
                      (r.facilities?.toLowerCase().contains(_searchQuery) ??
                          false);
                }).toList();

                if (filtered.isEmpty) {
                  return const KosMateEmptyState(
                    icon: Icons.sensor_door_outlined,
                    title: 'No rooms found',
                    subtitle: 'Try adjusting your search query.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final room = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Room ${room.roomNumber}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Available',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${room.house?.houseName ?? "Kos"} • ${room.roomType}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            if (room.facilities != null &&
                                room.facilities!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Facilities: ${room.facilities}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  Formatters.formatCurrency(room.price),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _showBookingDialog(room),
                                  child: const Text('Book Now'),
                                ),
                              ],
                            ),
                          ],
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
// TAB 2: PAYMENTS
// -----------------------------------------------------------------------------
class _TenantPaymentsTab extends StatefulWidget {
  final UserModel user;
  const _TenantPaymentsTab({required this.user});

  @override
  State<_TenantPaymentsTab> createState() => _TenantPaymentsTabState();
}

class _TenantPaymentsTabState extends State<_TenantPaymentsTab> {
  final _paymentService = PaymentService();
  late Future<List<PaymentModel>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() {
    setState(() {
      _paymentsFuture = _paymentService.getPaymentsByUser(widget.user.userId);
    });
  }

  void _startMidtransPayment(PaymentModel payment) async {
    // If invoice already has a generated Midtrans QR code, directly open sheet
    if (payment.qrCodeUrl != null && payment.orderId != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MidtransPaymentSheet(
          payment: payment,
          onPaymentSuccess: _loadPayments,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to Midtrans Core API...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final chargedPayment = await _paymentService.initiateMidtransPayment(
        payment: payment,
        tenant: widget.user,
      );
      if (mounted) Navigator.pop(context); // close loader dialog
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MidtransPaymentSheet(
          payment: chargedPayment,
          onPaymentSuccess: _loadPayments,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loader dialog
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to initialize GoPay/QRIS: $e')),
      );
    }
  }

  void _showSubmitReceiptDialog(PaymentModel payment) {
    final receiptController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Payment Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${Formatters.formatCurrency(payment.amount)}'),
            const SizedBox(height: 12),
            TextField(
              controller: receiptController,
              decoration: const InputDecoration(
                labelText: 'Receipt / Transfer Reference URL',
                hintText: 'https://...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (receiptController.text.trim().isEmpty) return;
              try {
                await _paymentService.submitReceipt(
                  paymentId: payment.paymentId,
                  receiptUrl: receiptController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadPayments();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Receipt submitted successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
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
          final payments = snapshot.data ?? [];
          if (payments.isEmpty) {
            return const KosMateEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No invoices yet',
              subtitle: 'Your payment history will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final p = payments[index];
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: p.status == PaymentStatus.paid
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.status.displayName,
                              style: TextStyle(
                                color: p.status == PaymentStatus.paid
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Due Date: ${Formatters.formatDate(p.dueDate)}'),
                      if (p.paidDate != null)
                        Text('Paid On: ${Formatters.formatDate(p.paidDate)}'),
                      if (p.orderId != null &&
                          p.status == PaymentStatus.pending) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Order ID: ${p.orderId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                      if (p.status == PaymentStatus.pending) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  p.qrCodeUrl != null
                                      ? 'Continue GoPay / QRIS'
                                      : 'Pay with GoPay / QRIS',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () => _startMidtransPayment(p),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.upload_file, size: 16),
                            label: const Text(
                              'Or submit manual receipt',
                              style: TextStyle(fontSize: 13),
                            ),
                            onPressed: () => _showSubmitReceiptDialog(p),
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
