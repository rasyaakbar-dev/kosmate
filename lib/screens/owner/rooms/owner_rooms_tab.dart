import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
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
  Map<int, List<RoomModel>> _houseRooms = {};
  final Map<int, String> _roomTenants = {};

  HouseModel? _selectedHouse;
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final houses = await _houseService.getHousesByOwner(
        widget.currentUser.userId,
      );
      _houses = houses;

      final Map<int, List<RoomModel>> roomMap = {};
      List<RoomModel> allRooms = [];

      for (final h in houses) {
        final rooms = await _roomService.getRooms(houseId: h.houseId);
        roomMap[h.houseId] = rooms;
        allRooms.addAll(rooms);
      }
      _houseRooms = roomMap;

      // Fetch active bookings for all rooms to get tenant names
      if (allRooms.isNotEmpty) {
        try {
          final roomIds = allRooms.map((r) => r.roomId).toList();
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

      // If a house was selected, update reference
      if (_selectedHouse != null) {
        final updatedHouse = houses.where(
          (h) => h.houseId == _selectedHouse!.houseId,
        );
        if (updatedHouse.isNotEmpty) {
          _selectedHouse = updatedHouse.first;
        } else {
          _selectedHouse = null;
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openAddHouseScreen() async {
    final created = await Navigator.push<HouseModel>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseFormScreen(ownerId: widget.currentUser.userId),
      ),
    );

    if (created != null && mounted) {
      await _loadData();
      setState(() {
        _selectedHouse = created;
      });
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
      await _loadData();
    }
  }

  Future<void> _deleteHouse(HouseModel house) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Boarding House'),
        content: Text(
          'Are you sure you want to delete "${house.houseName}"? All rooms in this house will also be deleted.',
        ),
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

    if (confirmed == true && mounted) {
      try {
        await _houseService.deleteHouse(house.houseId);
        if (_selectedHouse?.houseId == house.houseId) {
          _selectedHouse = null;
        }
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Boarding house deleted.'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete house: $e'),
              backgroundColor: AppTheme.destructiveColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _openAddRoomScreen([int? targetHouseId]) async {
    final houseId = targetHouseId ?? _selectedHouse?.houseId;
    if (_houses.isEmpty) {
      _openAddHouseScreen();
      return;
    }

    final created = await Navigator.push<RoomModel>(
      context,
      MaterialPageRoute(
        builder: (_) => RoomFormScreen(
          ownerId: widget.currentUser.userId,
          houseId: houseId,
        ),
      ),
    );

    if (created != null && mounted) {
      _loadData();
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
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: _selectedHouse == null
          ? _buildHouseDirectoryView()
          : _buildHouseRoomsView(),
    );
  }

  Widget _buildHouseDirectoryView() {
    final filteredHouses = _houses.where((h) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return h.houseName.toLowerCase().contains(q) ||
          h.houseAddress.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Boarding Houses',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Select a house to manage its rooms',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _openAddHouseScreen,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add House'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search houses by name or address...',
              prefixIcon: const Icon(
                Icons.search,
                color: AppTheme.textMuted,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 18,
                        color: AppTheme.destructiveColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderMedium),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderMedium),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.accentColor,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 18),

          if (_houses.isEmpty)
            _buildEmptyHousesState()
          else if (filteredHouses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No boarding houses match your search.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredHouses.length,
              itemBuilder: (context, idx) {
                final house = filteredHouses[idx];
                final rooms = _houseRooms[house.houseId] ?? [];
                final totalCount = rooms.length;
                final availableCount = rooms
                    .where((r) => r.status == RoomStatus.available)
                    .length;
                final occupiedCount = rooms
                    .where((r) => r.status == RoomStatus.occupied)
                    .length;

                return _buildHouseCard(
                  house: house,
                  totalCount: totalCount,
                  availableCount: availableCount,
                  occupiedCount: occupiedCount,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHouseCard({
    required HouseModel house,
    required int totalCount,
    required int availableCount,
    required int occupiedCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedHouse = house;
              _searchQuery = '';
              _searchController.clear();
              _selectedStatusFilter = 'All';
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: AppTheme.borderLight,
                    child:
                        house.thumbnailUrl != null &&
                            house.thumbnailUrl!.isNotEmpty
                        ? Image.network(
                            house.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.home_work_outlined,
                              size: 32,
                              color: AppTheme.textMuted,
                            ),
                          )
                        : const Icon(
                            Icons.home_work_outlined,
                            size: 32,
                            color: AppTheme.textMuted,
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              house.houseName,
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
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            onSelected: (val) {
                              if (val == 'edit') {
                                _openEditHouseScreen(house);
                              } else if (val == 'delete') {
                                _deleteHouse(house);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: AppTheme.primaryColor,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Edit House'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: AppTheme.destructiveColor,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete House',
                                      style: TextStyle(
                                        color: AppTheme.destructiveColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              house.houseAddress,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          _buildPillBadge(
                            label: '$totalCount Rooms',
                            bgColor: AppTheme.surfaceLight,
                            textColor: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          _buildPillBadge(
                            label: '$availableCount Available',
                            bgColor: AppTheme.successLight,
                            textColor: AppTheme.successColor,
                          ),
                          const SizedBox(width: 6),
                          _buildPillBadge(
                            label: '$occupiedCount Occupied',
                            bgColor: AppTheme.primaryLight,
                            textColor: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHousesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.home_work_outlined,
                size: 48,
                color: AppTheme.accentColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Boarding Houses Yet',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create your first boarding house to start managing its rooms and tenants.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openAddHouseScreen,
              icon: const Icon(Icons.add),
              label: const Text('Add Boarding House'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseRoomsView() {
    final house = _selectedHouse!;
    final rooms = _houseRooms[house.houseId] ?? [];

    final filteredRooms = rooms.where((r) {
      if (_selectedStatusFilter != 'All') {
        if (_selectedStatusFilter == 'Available' &&
            r.status != RoomStatus.available) {
          return false;
        }
        if (_selectedStatusFilter == 'Occupied' &&
            r.status != RoomStatus.occupied) {
          return false;
        }
        if (_selectedStatusFilter == 'Maintenance' &&
            r.status != RoomStatus.maintenance) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final numMatch = r.roomNumber.toLowerCase().contains(q);
        final typeMatch = r.roomType.toLowerCase().contains(q);
        final tenant = _roomTenants[r.roomId]?.toLowerCase() ?? '';
        final tenantMatch = tenant.contains(q);
        return numMatch || typeMatch || tenantMatch;
      }
      return true;
    }).toList();

    final totalCount = rooms.length;
    final availableCount = rooms
        .where((r) => r.status == RoomStatus.available)
        .length;
    final occupiedCount = rooms
        .where((r) => r.status == RoomStatus.occupied)
        .length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedHouse = null;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppTheme.foregroundColor,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      house.houseName,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      house.houseAddress,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
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
              ElevatedButton.icon(
                onPressed: () => _openAddRoomScreen(house.houseId),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatPill('Total', '$totalCount', AppTheme.primaryColor),
                Container(width: 1, height: 20, color: AppTheme.borderMedium),
                _buildStatPill(
                  'Available',
                  '$availableCount',
                  AppTheme.successColor,
                ),
                Container(width: 1, height: 20, color: AppTheme.borderMedium),
                _buildStatPill(
                  'Occupied',
                  '$occupiedCount',
                  AppTheme.accentColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search room number, type, or tenant...',
              prefixIcon: const Icon(
                Icons.search,
                color: AppTheme.textMuted,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 18,
                        color: AppTheme.destructiveColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 14,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderMedium),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderMedium),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.accentColor,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Available', 'Occupied', 'Maintenance'].map((
                status,
              ) {
                final isSelected = _selectedStatusFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    showCheckmark: false,
                    checkmarkColor: AppTheme.accentColor,
                    selectedColor: AppTheme.primaryLight,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.accentColor
                          : AppTheme.borderMedium,
                    ),
                    labelStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: isSelected
                          ? AppTheme.accentColor
                          : AppTheme.textDark,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedStatusFilter = status);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          if (rooms.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.sensor_door_outlined,
                      size: 44,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No rooms in this boarding house yet.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add your first room to make it available for tenants.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _openAddRoomScreen(house.houseId),
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Room'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (filteredRooms.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No rooms match your filter.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredRooms.length,
              itemBuilder: (context, idx) {
                final room = filteredRooms[idx];
                final tenantName = _roomTenants[room.roomId];
                return _buildRoomTile(room: room, tenantName: tenantName);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRoomTile({required RoomModel room, String? tenantName}) {
    Color badgeBg;
    Color badgeText;
    switch (room.status) {
      case RoomStatus.available:
        badgeBg = AppTheme.successLight;
        badgeText = AppTheme.successColor;
        break;
      case RoomStatus.occupied:
        badgeBg = AppTheme.primaryLight;
        badgeText = AppTheme.primaryColor;
        break;
      case RoomStatus.maintenance:
        badgeBg = AppTheme.destructiveLight;
        badgeText = AppTheme.destructiveColor;
        break;
      case RoomStatus.unavailable:
        badgeBg = AppTheme.surfaceLight;
        badgeText = AppTheme.textMuted;
        break;
    }

    final hasPhoto = room.imageUrls.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openRoomDetails(room),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: AppTheme.surfaceLight,
                    child: hasPhoto
                        ? Image.network(
                            room.imageUrls.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.meeting_room_outlined,
                              color: AppTheme.accentColor,
                            ),
                          )
                        : const Icon(
                            Icons.meeting_room_outlined,
                            color: AppTheme.accentColor,
                            size: 26,
                          ),
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
                            room.roomNumber,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.foregroundColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              room.status.displayName,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: badgeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        room.roomType,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${Formatters.formatCurrency(room.price)} / mo',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          if (tenantName != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 13,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  tenantName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSubtle,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillBadge({
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
