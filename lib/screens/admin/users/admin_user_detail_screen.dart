import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/complaint_response_sheet.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../core/widgets/payment_detail_sheet.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/house_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';
import '../../houses/house_detail_screen.dart';
import '../../owner/rooms/room_detail_screen.dart';
import '../payments/admin_payment_form_screen.dart';
import 'admin_user_form_screen.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final UserModel user;
  final UserModel? currentUser;

  const AdminUserDetailScreen({
    super.key,
    required this.user,
    this.currentUser,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final _bookingService = sl.booking;
  final _paymentService = sl.payment;
  final _complaintService = sl.complaint;
  final _houseService = sl.house;
  final _roomService = sl.room;
  final _userService = sl.user;

  late UserModel _user;
  List<BookingModel> _bookings = [];
  List<PaymentModel> _payments = [];
  List<ComplaintModel> _complaints = [];
  List<HouseModel> _houses = [];
  Map<int, List<RoomModel>> _houseRooms = {};

  bool _isLoading = true;

  UserModel get _viewer =>
      widget.currentUser ??
      UserModel(
        userId: 0,
        name: 'Admin',
        email: '',
        phone: '',
        role: UserRole.admin,
        createdAt: DateTime.now(),
      );

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final refreshedUser = await _userService.getUserById(_user.userId);
      if (refreshedUser != null) _user = refreshedUser;

      List<BookingModel> bookings = [];
      List<PaymentModel> payments = [];
      List<ComplaintModel> complaints = [];
      List<HouseModel> houses = [];
      final Map<int, List<RoomModel>> houseRooms = {};

      if (_user.role == UserRole.owner) {
        houses = await _houseService.getHousesByOwner(_user.userId);
        for (final h in houses) {
          houseRooms[h.houseId] = await _roomService.getRooms(
            houseId: h.houseId,
          );
        }
      } else if (_user.role == UserRole.tenant) {
        bookings = await _bookingService.getBookingsByUser(_user.userId);
        payments = await _paymentService.getPaymentsByUser(_user.userId);
        complaints = await _complaintService.getComplaintsByUser(_user.userId);
      }

      if (mounted) {
        setState(() {
          _bookings = bookings;
          _payments = payments;
          _complaints = complaints;
          _houses = houses;
          _houseRooms = houseRooms;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEditUser() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminUserFormScreen(user: _user)),
    );
    if (updated == true && mounted) {
      _loadUserData();
    }
  }

  Future<void> _openPaymentForm([PaymentModel? payment]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPaymentFormScreen(
          payment: payment,
          initialUserId: payment == null ? _user.userId : null,
        ),
      ),
    );
    if (changed == true && mounted) {
      _loadUserData();
    }
  }

  Future<void> _openHouseDetail(HouseModel house) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseDetailScreen(house: house, currentUser: _viewer),
      ),
    );
    if (changed == true && mounted) {
      _loadUserData();
    }
  }

  Future<void> _openRoomDetail(RoomModel room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomDetailScreen(room: room, currentUser: _viewer),
      ),
    );
    if (mounted) {
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (_user.avatarUrl != null && _user.avatarUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_user.avatarUrl!);
    }

    return Scaffold(
      appBar: KosMateAppBar(title: _user.name, showBackButton: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: AppTheme.primaryLight,
                                backgroundImage: avatarImage,
                                child: avatarImage == null
                                    ? Text(
                                        _user.name.isNotEmpty
                                            ? _user.name[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _user.name,
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.foregroundColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        _buildRoleBadge(_user.role),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _user.email,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    if (_user.phone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _user.phone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSubtle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openEditUser,
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit User & Photo'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: const BorderSide(
                                  color: AppTheme.primaryColor,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_user.role == UserRole.owner) ...[
                      _buildSectionHeader(
                        title: 'Owned Boarding Houses',
                        count: '${_houses.length}',
                        icon: Icons.apartment_outlined,
                      ),
                      const SizedBox(height: 10),
                      if (_houses.isEmpty)
                        _buildEmptyTile(
                          'No boarding houses listed for this owner.',
                        )
                      else
                        ..._houses.map((h) => _buildHouseTile(h)),
                      const SizedBox(height: 22),
                      Builder(
                        builder: (context) {
                          final allRooms =
                              <({HouseModel house, RoomModel room})>[];
                          for (final h in _houses) {
                            final rooms = _houseRooms[h.houseId] ?? [];
                            for (final r in rooms) {
                              allRooms.add((house: h, room: r));
                            }
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                title: 'Owned Rooms',
                                count: '${allRooms.length}',
                                icon: Icons.meeting_room_outlined,
                              ),
                              const SizedBox(height: 10),
                              if (allRooms.isEmpty)
                                _buildEmptyTile(
                                  'No rooms added to these houses yet.',
                                )
                              else
                                ...allRooms.map(
                                  (entry) => _buildOwnerRoomTile(
                                    entry.room,
                                    entry.house,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ] else if (_user.role == UserRole.tenant) ...[
                      _buildSectionHeader(
                        title: 'Booked Room & Boarding House',
                        count: '${_bookings.length}',
                        icon: Icons.meeting_room_outlined,
                      ),
                      const SizedBox(height: 10),
                      if (_bookings.isEmpty)
                        _buildEmptyTile(
                          'No active room assignments or bookings.',
                        )
                      else
                        ..._bookings.map((b) => _buildBookingTile(b)),
                      const SizedBox(height: 22),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildSectionHeader(
                              title: 'Payments & Invoices',
                              count: '${_payments.length}',
                              icon: Icons.receipt_long_outlined,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _openPaymentForm(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New Invoice'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_payments.isEmpty)
                        _buildEmptyTile('No payments or invoices on record.')
                      else
                        ..._payments.map((p) => _buildPaymentTile(p)),
                      const SizedBox(height: 22),

                      _buildSectionHeader(
                        title: 'Complaints',
                        count: '${_complaints.length}',
                        icon: Icons.feedback_outlined,
                      ),
                      const SizedBox(height: 10),
                      if (_complaints.isEmpty)
                        _buildEmptyTile('No complaints submitted.')
                      else
                        ..._complaints.map((c) => _buildComplaintTile(c)),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'System Administrator account with full platform management privileges.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String count,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.accentColor, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTile(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
      ),
    );
  }

  Widget _buildBookingTile(BookingModel b) {
    final room = b.room;
    final house = room?.house;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: room != null ? () => _openRoomDetail(room) : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.meeting_room_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${room?.roomNumber ?? b.roomId} - ${house?.houseName ?? "Boarding House"}',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foregroundColor,
                        ),
                      ),
                      Text(
                        'Status: ${b.status.displayName} • Request: ${Formatters.formatDate(b.requestDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (room != null)
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.textSubtle,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHouseTile(HouseModel h) {
    final rooms = _houseRooms[h.houseId] ?? [];
    final availableCount = rooms
        .where((r) => r.status == RoomStatus.available)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openHouseDetail(h),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.apartment_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.houseName,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foregroundColor,
                        ),
                      ),
                      Text(
                        h.houseAddress,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rooms.length} rooms • $availableCount available',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.textSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerRoomTile(RoomModel r, HouseModel house) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openRoomDetail(r.copyWith(house: house)),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBadgeBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.meeting_room_outlined,
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
                        'Room ${r.roomNumber} • ${house.houseName}',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foregroundColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${r.roomType} • ${Formatters.formatCurrency(r.price)}/mo',
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
                KosMateStatusChip.fromRoomStatus(r.status),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.textSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => PaymentDetailSheet.show(
            context,
            p,
            onEdit: () => _openPaymentForm(p),
          ),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBadgeBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppTheme.accentColor,
                    size: 20,
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
                          Text(
                            Formatters.formatCurrency(p.amount),
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.status.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Due: ${Formatters.formatDate(p.dueDate)} • Room ${p.room?.roomNumber ?? p.roomId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComplaintTile(ComplaintModel c) {
    Color badgeBg;
    Color badgeText;
    switch (c.status) {
      case ComplaintStatus.resolved:
        badgeBg = AppTheme.successLight;
        badgeText = AppTheme.successColor;
        break;
      case ComplaintStatus.inProgress:
        badgeBg = AppTheme.warningLight;
        badgeText = AppTheme.warningColor;
        break;
      case ComplaintStatus.pending:
        badgeBg = AppTheme.surfaceLight;
        badgeText = AppTheme.primaryColor;
        break;
      case ComplaintStatus.rejected:
        badgeBg = AppTheme.destructiveLight;
        badgeText = AppTheme.destructiveColor;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              ComplaintResponseSheet.show(context, c, onUpdated: _loadUserData),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.build_circle_outlined,
                    color: AppTheme.accentColor,
                    size: 20,
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
                              c.title,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.foregroundColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c.status.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeText,
                              ),
                            ),
                          ),
                        ],
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
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.textSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    Color bg;
    Color fg;
    String label;

    switch (role) {
      case UserRole.admin:
        bg = AppTheme.destructiveLight;
        fg = AppTheme.destructiveColor;
        label = 'ADMIN';
        break;
      case UserRole.owner:
        bg = AppTheme.warningLight;
        fg = AppTheme.warningColor;
        label = 'OWNER';
        break;
      case UserRole.tenant:
        bg = AppTheme.primaryLight;
        fg = AppTheme.primaryColor;
        label = 'TENANT';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
