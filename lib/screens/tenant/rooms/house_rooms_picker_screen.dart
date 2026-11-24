import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../models/house_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';

class HouseRoomsPickerScreen extends StatefulWidget {
  final HouseModel house;
  final UserModel user;

  const HouseRoomsPickerScreen({
    super.key,
    required this.house,
    required this.user,
  });

  @override
  State<HouseRoomsPickerScreen> createState() => _HouseRoomsPickerScreenState();
}

class _HouseRoomsPickerScreenState extends State<HouseRoomsPickerScreen> {
  final _roomService = sl.room;
  final _bookingService = sl.booking;

  late Future<List<RoomModel>> _roomsFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  void _loadRooms() {
    setState(() {
      _roomsFuture = _roomService.getRooms(
        houseId: widget.house.houseId,
        status: RoomStatus.available,
      );
    });
  }

  void _showBookingRequestDialog(RoomModel room) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Book Room',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foregroundColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.house.houseName} • Room ${room.roomNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.meeting_room_outlined,
                          color: AppTheme.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Room ${room.roomNumber} (${room.roomType})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.foregroundColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${Formatters.formatCurrency(room.price)} / month',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Desired Move-in Date *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setModalState(() => selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderMedium),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          Formatters.formatDate(selectedDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: AppTheme.accentColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Notes for Owner (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Student at Telkom University, bringing motorcycle...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSubtle,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.borderMedium,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.borderMedium,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.accentColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.textMuted,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your booking request will be reviewed by the boarding house owner. Once approved, your tenancy will commence.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: const BorderSide(color: AppTheme.borderMedium),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                setModalState(() => _isSubmitting = true);
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(context);
                                try {
                                  await _bookingService.createBooking(
                                    userId: widget.user.userId,
                                    roomId: room.roomId,
                                    requestDate: selectedDate,
                                    notes:
                                        notesController.text.trim().isNotEmpty
                                        ? notesController.text.trim()
                                        : null,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  nav.pop(true);
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Booking request submitted! The owner will review your request.',
                                      ),
                                      backgroundColor: AppTheme.successColor,
                                    ),
                                  );
                                } catch (e) {
                                  setModalState(() => _isSubmitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Request Booking',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: KosMateAppBar(
        title: widget.house.houseName,
        showBackButton: true,
        showLogo: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadRooms(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 64,
                            height: 64,
                            color: AppTheme.borderLight,
                            child:
                                widget.house.thumbnailUrl != null &&
                                    widget.house.thumbnailUrl!.trim().isNotEmpty
                                ? Image.network(
                                    widget.house.thumbnailUrl!.trim(),
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
                                widget.house.houseName,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.foregroundColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.house.houseAddress,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.house.description != null &&
                        widget.house.description!.trim().isNotEmpty) ...[
                      const Divider(height: 20, color: AppTheme.surfaceLight),
                      Text(
                        widget.house.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Available Rooms',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foregroundColor,
                ),
              ),
              const SizedBox(height: 12),

              FutureBuilder<List<RoomModel>>(
                future: _roomsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final rooms = snapshot.data ?? [];
                  if (rooms.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 40,
                            color: AppTheme.borderMedium,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No available rooms in this boarding house right now.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rooms.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = rooms[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.meeting_room_outlined,
                                color: AppTheme.accentColor,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Room ${r.roomNumber}',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.foregroundColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.roomType,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${Formatters.formatCurrency(r.price)} / mo',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _showBookingRequestDialog(r),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Book',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
