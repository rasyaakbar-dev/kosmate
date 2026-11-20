import 'package:flutter/material.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../models/user_model.dart';
import '../admin/users/user_form_dialog.dart';
import '../houses/house_form_screen.dart';
import '../owner/rooms/room_form_screen.dart';
import '../shared_crud/booking_form_screen.dart';
import '../shared_crud/complaint_form_screen.dart';
import '../shared_crud/payment_form_screen.dart';

class CrudTestScreen extends StatefulWidget {
  final UserModel currentUser;

  const CrudTestScreen({super.key, required this.currentUser});

  @override
  State<CrudTestScreen> createState() => _CrudTestScreenState();
}

class _CrudTestScreenState extends State<CrudTestScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  int _userCount = 0;
  int _houseCount = 0;
  int _roomCount = 0;
  int _bookingCount = 0;
  int _paymentCount = 0;
  int _complaintCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllCounts();
  }

  Future<void> _loadAllCounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final u = await supabase.from(SupabaseConstants.usersTable).select('user_id');
      final h = await supabase.from(SupabaseConstants.houseTable).select('house_id');
      final r = await supabase.from(SupabaseConstants.roomTable).select('room_id');
      final b = await supabase.from(SupabaseConstants.bookingTable).select('booking_id');
      final p = await supabase.from(SupabaseConstants.paymentTable).select('payment_id');
      final c = await supabase.from(SupabaseConstants.complaintTable).select('complaint_id');

      if (mounted) {
        setState(() {
          _userCount = (u as List).length;
          _houseCount = (h as List).length;
          _roomCount = (r as List).length;
          _bookingCount = (b as List).length;
          _paymentCount = (p as List).length;
          _complaintCount = (c as List).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: KosMateAppBar(
        title: 'CRUD Testing Hub',
        showBackButton: true,
        showLogo: false,
        showHelp: false,
        actionIcon: Icons.refresh_rounded,
        onActionPressed: _loadAllCounts,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllCounts,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _errorMessage == null
                          ? const Color(0xFFE6F4EA)
                          : const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _errorMessage == null
                            ? const Color(0xFF34A853)
                            : const Color(0xFFE02424),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _errorMessage == null
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                          color: _errorMessage == null
                              ? const Color(0xFF137333)
                              : const Color(0xFF9B1C1C),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _errorMessage == null
                                    ? 'Supabase Connected & Healthy'
                                    : 'Connection Issue Detected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _errorMessage == null
                                      ? const Color(0xFF137333)
                                      : const Color(0xFF9B1C1C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _errorMessage == null
                                    ? 'Realtime queries to all 6 schema tables succeeded.'
                                    : _errorMessage!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Database Entities & CRUD Operations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildEntityCard(
                    title: '1. Users',
                    table: SupabaseConstants.usersTable,
                    count: _userCount,
                    icon: Icons.person_outline_rounded,
                    actionLabel: 'Create User',
                    onAction: () async {
                      final created = await UserFormDialog.show(context);
                      if (created == true) _loadAllCounts();
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildEntityCard(
                    title: '2. Boarding Houses',
                    table: SupabaseConstants.houseTable,
                    count: _houseCount,
                    icon: Icons.apartment_rounded,
                    actionLabel: 'Create House',
                    onAction: () async {
                      final created = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HouseFormScreen(ownerId: widget.currentUser.userId),
                        ),
                      );
                      if (created != null) _loadAllCounts();
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildEntityCard(
                    title: '3. Rooms',
                    table: SupabaseConstants.roomTable,
                    count: _roomCount,
                    icon: Icons.sensor_door_outlined,
                    actionLabel: 'Create Room',
                    onAction: () async {
                      final created = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoomFormScreen(ownerId: widget.currentUser.userId),
                        ),
                      );
                      if (created != null) _loadAllCounts();
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildEntityCard(
                    title: '4. Bookings',
                    table: SupabaseConstants.bookingTable,
                    count: _bookingCount,
                    icon: Icons.event_available_outlined,
                    actionLabel: 'New Booking',
                    onAction: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingFormScreen(initialUserId: widget.currentUser.userId),
                        ),
                      );
                      if (created == true) _loadAllCounts();
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildEntityCard(
                    title: '5. Invoices & Payments',
                    table: SupabaseConstants.paymentTable,
                    count: _paymentCount,
                    icon: Icons.receipt_long_outlined,
                    actionLabel: 'Issue Invoice',
                    onAction: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentFormScreen(initialUserId: widget.currentUser.userId),
                        ),
                      );
                      if (created == true) _loadAllCounts();
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildEntityCard(
                    title: '6. Complaints / Tickets',
                    table: SupabaseConstants.complaintTable,
                    count: _complaintCount,
                    icon: Icons.build_circle_outlined,
                    actionLabel: 'File Complaint',
                    onAction: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ComplaintFormScreen(initialUserId: widget.currentUser.userId),
                        ),
                      );
                      if (created == true) _loadAllCounts();
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEntityCard({
    required String title,
    required String table,
    required int count,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Table "$table" • $count records',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onAction,
              child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
