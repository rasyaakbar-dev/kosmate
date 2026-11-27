import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/complaint_response_sheet.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
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
import 'widgets/user_detail_tiles.dart';

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
                                        UserRoleBadge(role: _user.role),
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
                      UserDetailSectionHeader(
                        title: 'Owned Boarding Houses',
                        count: '${_houses.length}',
                        icon: Icons.apartment_outlined,
                      ),
                      const SizedBox(height: 10),
                      if (_houses.isEmpty)
                        const UserDetailEmptyTile(
                          text: 'No boarding houses listed for this owner.',
                        )
                      else
                        ..._houses.map(
                          (h) => UserDetailHouseTile(
                            house: h,
                            rooms: _houseRooms[h.houseId] ?? [],
                            onTap: () => _openHouseDetail(h),
                          ),
                        ),
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
                              UserDetailSectionHeader(
                                title: 'Owned Rooms',
                                count: '${allRooms.length}',
                                icon: Icons.meeting_room_outlined,
                              ),
                              const SizedBox(height: 10),
                              if (allRooms.isEmpty)
                                const UserDetailEmptyTile(
                                  text: 'No rooms added to these houses yet.',
                                )
                              else
                                ...allRooms.map(
                                  (entry) => UserDetailOwnerRoomTile(
                                    room: entry.room,
                                    house: entry.house,
                                    onTap: () => _openRoomDetail(
                                      entry.room.copyWith(house: entry.house),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ] else if (_user.role == UserRole.tenant) ...[
                      UserDetailSectionHeader(
                        title: 'Booked Room & Boarding House',
                        count: '${_bookings.length}',
                        icon: Icons.meeting_room_outlined,
                      ),
                      const SizedBox(height: 10),
                      if (_bookings.isEmpty)
                        const UserDetailEmptyTile(
                          text: 'No active room assignments or bookings.',
                        )
                      else
                        ..._bookings.map(
                          (b) => UserDetailBookingTile(
                            booking: b,
                            onTap: b.room != null
                                ? () => _openRoomDetail(b.room!)
                                : null,
                          ),
                        ),
                      const SizedBox(height: 22),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: UserDetailSectionHeader(
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
                        const UserDetailEmptyTile(
                          text: 'No payments or invoices on record.',
                        )
                      else
                        ..._payments.map(
                          (p) => UserDetailPaymentTile(
                            payment: p,
                            onTap: () => PaymentDetailSheet.show(
                              context,
                              p,
                              onEdit: () => _openPaymentForm(p),
                            ),
                          ),
                        ),
                      const SizedBox(height: 22),

                      UserDetailSectionHeader(
                        title: 'Complaints',
                        count: '${_complaints.length}',
                        icon: Icons.feedback_outlined,
                      ),
                      const SizedBox(height: 10),
                      if (_complaints.isEmpty)
                        const UserDetailEmptyTile(
                          text: 'No complaints submitted.',
                        )
                      else
                        ..._complaints.map(
                          (c) => UserDetailComplaintTile(
                            complaint: c,
                            onTap: () => ComplaintResponseSheet.show(
                              context,
                              c,
                              onUpdated: _loadUserData,
                            ),
                          ),
                        ),
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
}
