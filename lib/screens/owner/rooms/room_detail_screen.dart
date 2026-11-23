import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/booking_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/payment_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';
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
  final _roomService = sl.room;
  final _complaintService = sl.complaint;
  late RoomModel _room;
  bool _isLoading = true;

  BookingModel? _activeBooking;
  PaymentModel? _currentPayment;
  List<ComplaintModel> _roomComplaints = [];

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

      // Fetch complaints for this room
      try {
        final complaintRes = await supabase
            .from(SupabaseConstants.complaintTable)
            .select(
              '*, users!complaint_user_id_fkey(*), room!complaint_room_id_fkey(*)',
            )
            .eq('room_id', _room.roomId)
            .order('created_at', ascending: false);
        if (mounted) {
          _roomComplaints = (complaintRes as List)
              .map(
                (row) => ComplaintModel.fromJson(row as Map<String, dynamic>),
              )
              .toList();
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

  void _showComplaintResponseDialog(ComplaintModel complaint) {
    final responseCtrl = TextEditingController(text: complaint.response ?? '');
    ComplaintStatus selectedStatus = complaint.status == ComplaintStatus.pending
        ? ComplaintStatus.inProgress
        : complaint.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(complaint.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tenant: ${complaint.user?.name ?? "Tenant"}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Description:\n${complaint.description}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ComplaintStatus>(
                  isExpanded: true,
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: ComplaintStatus.inProgress,
                      child: Text(
                        'In Progress',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    DropdownMenuItem(
                      value: ComplaintStatus.resolved,
                      child: Text(
                        'Resolved',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    DropdownMenuItem(
                      value: ComplaintStatus.rejected,
                      child: Text(
                        'Rejected',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
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
                    hintText: 'e.g., Plumber has completed the repairs.',
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _complaintService.respondToComplaint(
                    complaintId: complaint.complaintId,
                    responseText: responseCtrl.text.trim(),
                    status: selectedStatus,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  _loadRoomDetails();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Complaint updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
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
              backgroundColor: AppTheme.destructiveColor,
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
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: KosMateAppBar(
        title: 'Room details',
        showBackButton: true,
        showLogo: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: () {
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
                          color: AppTheme.destructiveColor,
                        ),
                        title: const Text(
                          'Delete Room',
                          style: TextStyle(color: AppTheme.destructiveColor),
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
        ],
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
                          color: AppTheme.iconBadgeBackground,
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
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$houseName • $floorLabel',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      KosMateStatusChip.fromRoomStatus(_room.status),
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
                        color: AppTheme.borderLight,
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
                            color: AppTheme.textDark,
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

                  // Current Status Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.borderColor.withValues(alpha: 0.3),
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
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
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
                                          ? Formatters.formatMonthYear(
                                              _currentPayment!.dueDate,
                                            )
                                          : 'Current Billing',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _currentPayment != null
                                          ? 'Due ${Formatters.formatShortDate(_currentPayment!.dueDate)}'
                                          : 'No active dues recorded',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              KosMateStatusChip.fromPaymentStatus(
                                _currentPayment?.status ?? PaymentStatus.paid,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Maintenance & Complaints section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.borderLight,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Maintenance & Complaints',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_roomComplaints.isEmpty)
                          const Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                                color: AppTheme.successColor,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'No maintenance tickets for this room',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ],
                          )
                        else
                          ...List.generate(_roomComplaints.length, (i) {
                            final c = _roomComplaints[i];
                            return Padding(
                              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                              child: InkWell(
                                onTap: () => _showComplaintResponseDialog(c),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTheme.borderLight,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.build_outlined,
                                        size: 18,
                                        color: AppTheme.accentColor,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          c.title,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      KosMateStatusChip.fromComplaintStatus(
                                        c.status,
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: AppTheme.accentColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
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
                            foregroundColor: AppTheme.destructiveColor,
                            side: const BorderSide(
                              color: AppTheme.destructiveColor,
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

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: AppTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
