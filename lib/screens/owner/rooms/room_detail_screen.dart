import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';
import '../../../services/room_service.dart';
import 'room_form_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  final RoomModel room;
  final UserModel currentUser;

  const RoomDetailScreen({
    super.key,
    required this.room,
    required this.currentUser,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final _roomService = RoomService();
  late RoomModel _room;
  bool _isLoading = true;

  BookingModel? _activeBooking;
  PaymentModel? _currentPayment;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _loadRoomDetails();
  }

  Future<void> _loadRoomDetails() async {
    try {
      final updatedRoom = await _roomService.getRoomById(_room.roomId);
      if (updatedRoom != null && mounted) {
        _room = updatedRoom;
      }

      // Fetch active booking if room is occupied
      try {
        final bookingRes = await supabase
            .from(SupabaseConstants.bookingTable)
            .select('*, users!booking_user_id_fkey(*)')
            .eq('room_id', _room.roomId)
            .eq('status', BookingStatus.approved.name)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (bookingRes != null && mounted) {
          _activeBooking = BookingModel.fromJson(bookingRes);
        }
      } catch (_) {}

      // Fetch latest payment invoice for this room
      try {
        final paymentRes = await supabase
            .from(SupabaseConstants.paymentTable)
            .select('*, users!payment_user_id_fkey(*)')
            .eq('room_id', _room.roomId)
            .order('due_date', ascending: false)
            .limit(1)
            .maybeSingle();

        if (paymentRes != null && mounted) {
          _currentPayment = PaymentModel.fromJson(paymentRes);
        }
      } catch (_) {}

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Are you sure you want to delete ${_room.roomNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB33A3A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _roomService.deleteRoom(_room.roomId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete room: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _editRoom() async {
    final updated = await Navigator.push<RoomModel>(
      context,
      MaterialPageRoute(
        builder: (_) => RoomFormScreen(
          room: _room,
          houseId: _room.houseId,
          ownerId: widget.currentUser.userId,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _room = updated;
        _isLoading = true;
      });
      _loadRoomDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final houseName = _room.house?.houseName ?? 'Boarding House';
    final floorLabel = _room.roomType.isNotEmpty ? _room.roomType : 'Floor 1';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: KosMateAppBar(
        title: 'Room details',
        showBackButton: true,
        showLogo: false,
        showHelp: true,
        actionIcon: Icons.more_vert_rounded,
        onActionPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit Room'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _editRoom();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFB33A3A),
                    ),
                    title: const Text(
                      'Delete Room',
                      style: TextStyle(color: Color(0xFFB33A3A)),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteRoom();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Summary Card
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.meeting_room_outlined,
                          color: AppTheme.accentColor,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _room.roomNumber,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$houseName • $floorLabel',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusPill(_room.status),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Information Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Information',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          'Renter',
                          _activeBooking?.user?.name ??
                              (_room.status == RoomStatus.occupied
                                  ? 'Occupied (Unassigned)'
                                  : '-'),
                          isBold: true,
                        ),
                        const SizedBox(height: 14),
                        _buildInfoRow(
                          'Monthly rent',
                          Formatters.formatCurrency(_room.price),
                          isBold: true,
                        ),
                        const SizedBox(height: 14),
                        _buildInfoRow(
                          'Check-in',
                          _activeBooking != null
                              ? Formatters.formatDate(
                                  _activeBooking!.requestDate,
                                )
                              : '-',
                          isBold: true,
                        ),
                        const SizedBox(height: 14),
                        _buildInfoRow(
                          'Facilities',
                          _room.facilities?.isNotEmpty == true
                              ? _room.facilities!
                              : 'Standard facilities',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Current Status Box (Yellow Card from Figma)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9E7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFF9E8B5),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current status',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_outlined,
                                  color: AppTheme.accentColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentPayment != null
                                          ? 'Invoice #${_currentPayment!.paymentId}'
                                          : 'Current Billing',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _currentPayment != null
                                          ? 'Due ${Formatters.formatDate(_currentPayment!.dueDate)}'
                                          : 'No active dues recorded',
                                      style: const TextStyle(
                                        fontSize: 12,
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
                                  color:
                                      _currentPayment?.status ==
                                          PaymentStatus.paid
                                      ? const Color(0xFFE6F4EA)
                                      : const Color(0xFFFEF9E7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _currentPayment?.status.displayName ?? 'Paid',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        _currentPayment?.status ==
                                            PaymentStatus.paid
                                        ? const Color(0xFF1E7E34)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Action Buttons: Delete and Edit room
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _deleteRoom,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB33A3A),
                            side: const BorderSide(
                              color: Color(0xFFB33A3A),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _editRoom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Edit room',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusPill(RoomStatus status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case RoomStatus.available:
        bg = const Color(0xFFE6F4EA);
        text = const Color(0xFF1E7E34);
        label = 'Available';
        break;
      case RoomStatus.occupied:
        bg = const Color(0xFFEBF3FA);
        text = const Color(0xFF1D4ED8);
        label = 'Occupied';
        break;
      case RoomStatus.maintenance:
      case RoomStatus.unavailable:
        bg = const Color(0xFFFEF9E7);
        text = const Color(0xFFB45309);
        label = 'Repair';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
