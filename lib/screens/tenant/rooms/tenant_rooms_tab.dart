import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';

class TenantRoomsTab extends StatefulWidget {
  final UserModel user;
  const TenantRoomsTab({super.key, required this.user});

  @override
  State<TenantRoomsTab> createState() => _TenantRoomsTabState();
}

class _TenantRoomsTabState extends State<TenantRoomsTab> {
  final _roomService = sl.room;
  final _bookingService = sl.booking;

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
                                KosMateStatusChip.fromRoomStatus(room.status),
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
