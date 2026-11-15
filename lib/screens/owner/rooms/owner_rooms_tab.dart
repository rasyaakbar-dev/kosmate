import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/house_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';
import '../../../services/house_service.dart';
import '../../../services/room_service.dart';
import 'room_detail_screen.dart';
import 'room_form_screen.dart';

class OwnerRoomsTab extends StatefulWidget {
  final UserModel currentUser;

  const OwnerRoomsTab({super.key, required this.currentUser});

  @override
  State<OwnerRoomsTab> createState() => _OwnerRoomsTabState();
}

class _OwnerRoomsTabState extends State<OwnerRoomsTab> {
  final _roomService = RoomService();
  final _houseService = HouseService();
  final _searchController = TextEditingController();

  List<HouseModel> _houses = [];
  List<RoomModel> _allRooms = [];
  List<RoomModel> _filteredRooms = [];

  // Map roomId to tenant name for fast display
  final Map<int, String> _roomTenants = {};

  bool _isLoading = true;
  String _searchQuery = '';
  int? _selectedHouseFilter;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    try {
      final houses = await _houseService.getHousesByOwner(
        widget.currentUser.userId,
      );
      _houses = houses;

      List<RoomModel> rooms = [];
      for (final h in houses) {
        final houseRooms = await _roomService.getRooms(houseId: h.houseId);
        rooms.addAll(houseRooms);
      }

      // Fetch active bookings for these rooms to display tenant names
      if (rooms.isNotEmpty) {
        try {
          final roomIds = rooms.map((r) => r.roomId).toList();
          final bookingsRes = await supabase
              .from(SupabaseConstants.bookingTable)
              .select('room_id, users!booking_user_id_fkey(name)')
              .inFilter('room_id', roomIds)
              .eq('status', 'approved');

          _roomTenants.clear();
          for (final b in bookingsRes as List) {
            final rId = b['room_id'] as int?;
            final userObj = b['users'] as Map<String, dynamic>?;
            if (rId != null && userObj != null && userObj['name'] != null) {
              _roomTenants[rId] = userObj['name'].toString();
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _allRooms = rooms;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter() {
    var list = List<RoomModel>.from(_allRooms);

    if (_selectedHouseFilter != null) {
      list = list.where((r) => r.houseId == _selectedHouseFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final numberMatch = r.roomNumber.toLowerCase().contains(q);
        final floorMatch = r.roomType.toLowerCase().contains(q);
        final tenant = _roomTenants[r.roomId]?.toLowerCase() ?? '';
        final tenantMatch = tenant.contains(q);
        final houseMatch =
            r.house?.houseName.toLowerCase().contains(q) ?? false;
        return numberMatch || floorMatch || tenantMatch || houseMatch;
      }).toList();
    }

    _filteredRooms = list;
  }

  void _openAddRoomScreen() async {
    final created = await Navigator.push<RoomModel>(
      context,
      MaterialPageRoute(
        builder: (_) => RoomFormScreen(
          ownerId: widget.currentUser.userId,
          houseId: _selectedHouseFilter ?? _houses.firstOrNull?.houseId,
        ),
      ),
    );

    if (created != null && mounted) {
      _loadRooms();
    }
  }

  void _openRoomDetails(RoomModel room) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RoomDetailScreen(room: room, currentUser: widget.currentUser),
      ),
    );

    if (changed == true && mounted) {
      _loadRooms();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalCount = _filteredRooms.length;
    final availableCount = _filteredRooms
        .where((r) => r.status == RoomStatus.available)
        .length;

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: Column(
        children: [
          // Top search & filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                          _applyFilter();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search room or renter',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _applyFilter();
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Filter icon button for selecting house
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  child: PopupMenuButton<int?>(
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: AppTheme.accentColor,
                    ),
                    tooltip: 'Filter by boarding house',
                    initialValue: _selectedHouseFilter,
                    onSelected: (val) {
                      setState(() {
                        _selectedHouseFilter = val;
                        _applyFilter();
                      });
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem<int?>(
                        value: null,
                        child: Text('All Houses'),
                      ),
                      ..._houses.map(
                        (h) => PopupMenuItem<int?>(
                          value: h.houseId,
                          child: Text(h.houseName),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Count & availability badge row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalCount rooms',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$availableCount available',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E7E34),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rooms list
          Expanded(
            child: _filteredRooms.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.meeting_room_outlined,
                            size: 56,
                            color: Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No rooms found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap "+ Add room" below to create a room.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    itemCount: _filteredRooms.length,
                    itemBuilder: (context, index) {
                      final room = _filteredRooms[index];
                      final tenantName = _roomTenants[room.roomId];
                      final floor = room.roomType.isNotEmpty
                          ? room.roomType
                          : 'Floor 1';
                      final subtitleText = tenantName != null
                          ? '$tenantName • $floor'
                          : (room.status == RoomStatus.available
                                ? 'Available • $floor'
                                : (room.status == RoomStatus.maintenance
                                      ? 'Maintenance • $floor'
                                      : 'Occupied • $floor'));

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _openRoomDetails(room),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
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
                                    Icons.meeting_room_outlined,
                                    color: AppTheme.accentColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        room.roomNumber,
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitleText,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusPill(room.status),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Sticky Bottom "+ Add room" Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Add room',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _openAddRoomScreen,
              ),
            ),
          ),
        ],
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
}
