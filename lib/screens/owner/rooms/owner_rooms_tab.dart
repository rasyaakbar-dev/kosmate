import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/house_model.dart';
import '../../../models/room_model.dart';
import '../../../models/user_model.dart';
import '../../houses/house_form_screen.dart';
import 'room_detail_screen.dart';
import 'room_form_screen.dart';

class OwnerRoomsTab extends StatefulWidget {
  final UserModel currentUser;

  const OwnerRoomsTab({super.key, required this.currentUser});

  @override
  State<OwnerRoomsTab> createState() => _OwnerRoomsTabState();
}

class _OwnerRoomsTabState extends State<OwnerRoomsTab> {
  final _roomService = sl.room;
  final _houseService = sl.house;
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

  Future<void> _openAddHouseScreen() async {
    final created = await Navigator.push<HouseModel>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseFormScreen(ownerId: widget.currentUser.userId),
      ),
    );

    if (created != null && mounted) {
      await _loadRooms();
      setState(() {
        _selectedHouseFilter = created.houseId;
        _applyFilter();
      });

      if (!mounted) return;
      final wantAddRoom = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('House "${created.houseName}" Created!'),
          content: const Text(
            'Would you like to add the first room to this boarding house now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add Room Now'),
            ),
          ],
        ),
      );

      if (wantAddRoom == true && mounted) {
        _openAddRoomScreen();
      }
    }
  }

  Future<void> _openEditHouseScreen(HouseModel house) async {
    final updated = await Navigator.push<HouseModel>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HouseFormScreen(house: house, ownerId: widget.currentUser.userId),
      ),
    );

    if (updated != null && mounted) {
      _loadRooms();
    }
  }

  void _openAddRoomScreen() async {
    if (_houses.isEmpty) {
      _openAddHouseScreen();
      return;
    }

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

  Widget _buildHouseFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFEFF6FF),
        checkmarkColor: AppTheme.accentColor,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppTheme.accentColor : const Color(0xFF475569),
        ),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppTheme.accentColor : const Color(0xFFCBD5E1),
          width: isSelected ? 1.5 : 1.0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Guided Onboarding when owner has 0 boarding houses
    if (_houses.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRooms,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          size: 44,
                          color: AppTheme.accentColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Create Your First Boarding House',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Before you can add rooms and accept tenants, you need to set up a boarding house (e.g. Kost Melati).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          'Create Boarding House',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _openAddHouseScreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                    'Create boarding house',
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
                  onPressed: _openAddHouseScreen,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final totalCount = _filteredRooms.length;
    final availableCount = _filteredRooms
        .where((r) => r.status == RoomStatus.available)
        .length;

    HouseModel? currentSelectedHouse;
    if (_selectedHouseFilter != null) {
      for (final h in _houses) {
        if (h.houseId == _selectedHouseFilter) {
          currentSelectedHouse = h;
          break;
        }
      }
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: Column(
        children: [
          // Top search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: KosMateSearchBar(
              controller: _searchController,
              hintText: 'Search room or renter',
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                  _applyFilter();
                });
              },
              onClear: () {
                setState(() {
                  _searchQuery = '';
                  _applyFilter();
                });
              },
            ),
          ),

          // Horizontal Boarding House Switcher Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildHouseFilterChip(
                  label: 'All Houses (${_allRooms.length})',
                  isSelected: _selectedHouseFilter == null,
                  onTap: () {
                    setState(() {
                      _selectedHouseFilter = null;
                      _applyFilter();
                    });
                  },
                ),
                ..._houses.map((h) {
                  final houseRoomCount = _allRooms
                      .where((r) => r.houseId == h.houseId)
                      .length;
                  return _buildHouseFilterChip(
                    label: '${h.houseName} ($houseRoomCount)',
                    isSelected: _selectedHouseFilter == h.houseId,
                    onTap: () {
                      setState(() {
                        _selectedHouseFilter = h.houseId;
                        _applyFilter();
                      });
                    },
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: ActionChip(
                    avatar: const Icon(
                      Icons.add,
                      size: 16,
                      color: AppTheme.accentColor,
                    ),
                    label: const Text(
                      'New House',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    backgroundColor: const Color(0xFFEFF6FF),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: _openAddHouseScreen,
                  ),
                ),
              ],
            ),
          ),

          // House Info Strip when a specific house is selected
          if (currentSelectedHouse != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        currentSelectedHouse.houseAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () =>
                          _openEditHouseScreen(currentSelectedHouse!),
                      child: const Text(
                        'Edit House',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Count & availability badge row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 6.0,
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
                ? const KosMateEmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'No rooms found',
                    subtitle: 'Tap "+ Add room" below to create a room.',
                    plain: true,
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
                                KosMateStatusChip.fromRoomStatus(room.status),
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
}
