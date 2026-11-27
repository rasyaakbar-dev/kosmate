import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zoomable_image.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/list_controls.dart';
import '../../../models/booking_model.dart';
import '../../../models/house_model.dart';
import '../../../models/room_model.dart';

class HouseRoomsManagerView extends StatefulWidget {
  final int? filterOwnerId;
  final String title;
  final String subtitle;
  final String searchHint;
  final String emptyHousesSubtitle;
  final String emptyRoomsSubtitle;
  final bool showOwnerInfo;
  final Future<({bool changed, HouseModel? selectHouse})> Function(
    BuildContext context,
  )
  onAddHouse;
  final Future<bool> Function(BuildContext context, HouseModel house)
  onEditHouse;
  final Future<bool> Function(BuildContext context, int? targetHouseId)
  onAddRoom;
  final Future<bool> Function(BuildContext context, RoomModel room) onEditRoom;
  final Future<bool> Function(BuildContext context, RoomModel room)? onRoomTap;

  const HouseRoomsManagerView({
    super.key,
    this.filterOwnerId,
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.emptyHousesSubtitle,
    required this.emptyRoomsSubtitle,
    this.showOwnerInfo = false,
    required this.onAddHouse,
    required this.onEditHouse,
    required this.onAddRoom,
    required this.onEditRoom,
    this.onRoomTap,
  });

  @override
  State<HouseRoomsManagerView> createState() => _HouseRoomsManagerViewState();
}

class _HouseRoomsManagerViewState extends State<HouseRoomsManagerView> {
  final _roomService = sl.room;
  final _houseService = sl.house;
  final _searchController = TextEditingController();

  List<HouseModel> _houses = [];
  Map<int, List<RoomModel>> _houseRooms = {};
  final Map<int, String> _roomTenants = {};

  HouseModel? _selectedHouse;
  bool _isLoading = true;
  String _searchQuery = '';
  String _houseFilter = 'All';
  String _houseSortId = 'name_asc';
  int _housePage = 1;
  int _housePageSize = 10;

  String _selectedStatusFilter = 'All';
  String _roomSortId = 'room_asc';
  int _roomPage = 1;
  int _roomPageSize = 10;

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
      final houses = widget.filterOwnerId != null
          ? await _houseService.getHousesByOwner(widget.filterOwnerId!)
          : await _houseService.getAllHouses();
      _houses = houses;

      final Map<int, List<RoomModel>> roomMap = {};
      final List<RoomModel> allRooms = [];

      for (final h in houses) {
        final rooms = await _roomService.getRooms(houseId: h.houseId);
        roomMap[h.houseId] = rooms;
        allRooms.addAll(rooms);
      }
      _houseRooms = roomMap;

      if (allRooms.isNotEmpty) {
        try {
          final roomIds = allRooms.map((r) => r.roomId).toList();
          final bookings = await sl.booking.getBookingsByRoomIds(
            roomIds,
            status: BookingStatus.approved,
          );

          _roomTenants.clear();
          for (final b in bookings) {
            final tenantName = b.user?.name;
            if (tenantName != null && tenantName.isNotEmpty) {
              _roomTenants[b.roomId] = tenantName;
            }
          }
        } catch (_) {}
      }

      if (_selectedHouse != null) {
        final updated = houses.where(
          (h) => h.houseId == _selectedHouse!.houseId,
        );
        _selectedHouse = updated.isNotEmpty ? updated.first : null;
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

  Future<void> _handleAddHouse() async {
    final result = await widget.onAddHouse(context);
    if (!result.changed || !mounted) return;
    await _loadData();
    if (result.selectHouse != null && mounted) {
      setState(() => _selectedHouse = result.selectHouse);
    }
  }

  Future<void> _handleEditHouse(HouseModel house) async {
    final changed = await widget.onEditHouse(context, house);
    if (changed && mounted) {
      await _loadData();
    }
  }

  Future<void> _deleteHouse(HouseModel house) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Boarding House'),
        content: Text(
          'Are you sure you want to delete "${house.houseName}"?\n\n'
          'All rooms in this house will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructiveColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
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
              content: Text('Boarding house deleted successfully.'),
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

  Future<void> _handleAddRoom([int? targetHouseId]) async {
    if (_houses.isEmpty) {
      await _handleAddHouse();
      return;
    }
    final houseId = targetHouseId ?? _selectedHouse?.houseId;
    final changed = await widget.onAddRoom(context, houseId);
    if (changed && mounted) {
      await _loadData();
    }
  }

  Future<void> _handleRoomTap(RoomModel room) async {
    final changed = widget.onRoomTap != null
        ? await widget.onRoomTap!(context, room)
        : await widget.onEditRoom(context, room);
    if (changed && mounted) {
      await _loadData();
    }
  }

  Future<void> _handleEditRoom(RoomModel room) async {
    final changed = await widget.onEditRoom(context, room);
    if (changed && mounted) {
      await _loadData();
    }
  }

  Future<void> _deleteRoom(RoomModel room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text(
          'Are you sure you want to delete Room ${room.roomNumber}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructiveColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _roomService.deleteRoom(room.roomId);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room deleted successfully.'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete room: $e'),
              backgroundColor: AppTheme.destructiveColor,
            ),
          );
        }
      }
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
    final sortOptions = [
      KosMateSortOption<HouseModel>(
        id: 'name_asc',
        label: 'Name (A–Z)',
        comparator: (a, b) =>
            a.houseName.toLowerCase().compareTo(b.houseName.toLowerCase()),
      ),
      KosMateSortOption<HouseModel>(
        id: 'name_desc',
        label: 'Name (Z–A)',
        comparator: (a, b) =>
            b.houseName.toLowerCase().compareTo(a.houseName.toLowerCase()),
      ),
      KosMateSortOption<HouseModel>(
        id: 'rooms_desc',
        label: 'Most Rooms',
        comparator: (a, b) => (_houseRooms[b.houseId]?.length ?? 0).compareTo(
          _houseRooms[a.houseId]?.length ?? 0,
        ),
      ),
      KosMateSortOption<HouseModel>(
        id: 'avail_desc',
        label: 'Most Available',
        comparator: (a, b) {
          final aAvail = (_houseRooms[a.houseId] ?? [])
              .where((r) => r.status == RoomStatus.available)
              .length;
          final bAvail = (_houseRooms[b.houseId] ?? [])
              .where((r) => r.status == RoomStatus.available)
              .length;
          return bAvail.compareTo(aAvail);
        },
      ),
      KosMateSortOption<HouseModel>(
        id: 'newest',
        label: 'Newest',
        comparator: (a, b) => b.houseId.compareTo(a.houseId),
      ),
    ];

    final filteredHouses = _houses.where((h) {
      final rooms = _houseRooms[h.houseId] ?? [];
      final avail = rooms.where((r) => r.status == RoomStatus.available).length;
      if (_houseFilter == 'Has Available' && avail == 0) return false;
      if (_houseFilter == 'Full' && avail > 0) return false;

      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nameMatch = h.houseName.toLowerCase().contains(q);
      final addressMatch = h.houseAddress.toLowerCase().contains(q);
      final ownerMatch =
          widget.showOwnerInfo &&
          (h.owner?.name.toLowerCase().contains(q) ?? false);
      return nameMatch || addressMatch || ownerMatch;
    }).toList();

    final selectedSort = sortOptions.firstWhere(
      (s) => s.id == _houseSortId,
      orElse: () => sortOptions.first,
    );
    filteredHouses.sort(selectedSort.comparator);

    final paged = paginateList(filteredHouses, _housePage, _housePageSize);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.foregroundColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    KosMateHeaderActionButton(
                      icon: Icons.add,
                      label: 'Add House',
                      onPressed: _handleAddHouse,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                KosMateSearchField(
                  controller: _searchController,
                  hintText: widget.searchHint,
                  onChanged: (val) => setState(() {
                    _searchQuery = val.trim();
                    _housePage = 1;
                  }),
                ),
                const SizedBox(height: 10),
                KosMateFilterSortBar<HouseModel>(
                  filterOptions: const ['All', 'Has Available', 'Full'],
                  selectedFilter: _houseFilter,
                  onFilterChanged: (val) => setState(() {
                    _houseFilter = val;
                    _housePage = 1;
                  }),
                  sortOptions: sortOptions,
                  selectedSortId: _houseSortId,
                  onSortChanged: (val) => setState(() {
                    _houseSortId = val;
                    _housePage = 1;
                  }),
                  totalCount: filteredHouses.length,
                  itemLabel: filteredHouses.length == 1 ? 'house' : 'houses',
                ),
                const SizedBox(height: 14),
                if (_houses.isEmpty)
                  _buildEmptyHousesState()
                else if (filteredHouses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No boarding houses match your search or filter.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: paged.pageItems.length,
                    itemBuilder: (context, idx) {
                      final house = paged.pageItems[idx];
                      final rooms = _houseRooms[house.houseId] ?? [];
                      return _buildHouseCard(
                        house: house,
                        totalCount: rooms.length,
                        availableCount: rooms
                            .where((r) => r.status == RoomStatus.available)
                            .length,
                        occupiedCount: rooms
                            .where((r) => r.status == RoomStatus.occupied)
                            .length,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        if (_houses.isNotEmpty && filteredHouses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: KosMatePaginationBar(
              currentPage: paged.safePage,
              totalPages: paged.totalPages,
              totalItems: filteredHouses.length,
              startIndex: paged.startIndex,
              endIndex: paged.endIndex,
              pageSize: _housePageSize,
              onPageChanged: (p) => setState(() => _housePage = p),
              onPageSizeChanged: (s) => setState(() {
                _housePageSize = s;
                _housePage = 1;
              }),
            ),
          ),
      ],
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
              _roomPage = 1;
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                        ? ZoomableImage(
                            imageProvider: NetworkImage(house.thumbnailUrl!),
                            child: Image.network(
                              house.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.home_work_outlined,
                                size: 32,
                                color: AppTheme.textMuted,
                              ),
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
                            constraints: const BoxConstraints(),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _handleEditHouse(house);
                              } else if (val == 'delete') {
                                _deleteHouse(house);
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(
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
                              PopupMenuItem(
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
                      if (widget.showOwnerInfo && house.owner != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 13,
                              color: AppTheme.accentColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Owner: ${house.owner!.name}',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accentColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildPillBadge(
                            label: '$totalCount Rooms',
                            bgColor: AppTheme.surfaceLight,
                            textColor: AppTheme.primaryColor,
                          ),
                          _buildPillBadge(
                            label: '$availableCount Available',
                            bgColor: AppTheme.successLight,
                            textColor: AppTheme.successColor,
                          ),
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
            Text(
              widget.emptyHousesSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _handleAddHouse,
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

    final roomSortOptions = [
      KosMateSortOption<RoomModel>(
        id: 'room_asc',
        label: 'Room # (A–Z)',
        comparator: (a, b) =>
            a.roomNumber.toLowerCase().compareTo(b.roomNumber.toLowerCase()),
      ),
      KosMateSortOption<RoomModel>(
        id: 'price_asc',
        label: 'Price: Low to High',
        comparator: (a, b) => a.price.compareTo(b.price),
      ),
      KosMateSortOption<RoomModel>(
        id: 'price_desc',
        label: 'Price: High to Low',
        comparator: (a, b) => b.price.compareTo(a.price),
      ),
      KosMateSortOption<RoomModel>(
        id: 'status',
        label: 'Status',
        comparator: (a, b) => a.status.name.compareTo(b.status.name),
      ),
    ];

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
        return numMatch || typeMatch || tenant.contains(q);
      }
      return true;
    }).toList();

    final selectedSort = roomSortOptions.firstWhere(
      (s) => s.id == _roomSortId,
      orElse: () => roomSortOptions.first,
    );
    filteredRooms.sort(selectedSort.comparator);

    final paged = paginateList(filteredRooms, _roomPage, _roomPageSize);

    final totalCount = rooms.length;
    final availableCount = rooms
        .where((r) => r.status == RoomStatus.available)
        .length;
    final occupiedCount = rooms
        .where((r) => r.status == RoomStatus.occupied)
        .length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 14.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedHouse = null;
                          _searchQuery = '';
                          _searchController.clear();
                          _housePage = 1;
                        });
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppTheme.foregroundColor,
                      ),
                      tooltip: 'Back to houses',
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
                    KosMateHeaderActionButton(
                      icon: Icons.add,
                      label: 'Add Room',
                      onPressed: () => _handleAddRoom(house.houseId),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatPill(
                        'Total',
                        '$totalCount',
                        AppTheme.primaryColor,
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: AppTheme.borderMedium,
                      ),
                      _buildStatPill(
                        'Available',
                        '$availableCount',
                        AppTheme.successColor,
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: AppTheme.borderMedium,
                      ),
                      _buildStatPill(
                        'Occupied',
                        '$occupiedCount',
                        AppTheme.accentColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                KosMateSearchField(
                  controller: _searchController,
                  hintText: 'Search room number, type, or tenant...',
                  onChanged: (val) => setState(() {
                    _searchQuery = val.trim();
                    _roomPage = 1;
                  }),
                ),
                const SizedBox(height: 10),
                KosMateFilterSortBar<RoomModel>(
                  filterOptions: const [
                    'All',
                    'Available',
                    'Occupied',
                    'Maintenance',
                  ],
                  selectedFilter: _selectedStatusFilter,
                  onFilterChanged: (status) => setState(() {
                    _selectedStatusFilter = status;
                    _roomPage = 1;
                  }),
                  sortOptions: roomSortOptions,
                  selectedSortId: _roomSortId,
                  onSortChanged: (val) => setState(() {
                    _roomSortId = val;
                    _roomPage = 1;
                  }),
                  totalCount: filteredRooms.length,
                  itemLabel: filteredRooms.length == 1 ? 'room' : 'rooms',
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
                          Text(
                            widget.emptyRoomsSubtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _handleAddRoom(house.houseId),
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
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: paged.pageItems.length,
                    itemBuilder: (context, idx) {
                      final room = paged.pageItems[idx];
                      return _buildRoomTile(
                        room: room,
                        tenantName: _roomTenants[room.roomId],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        if (rooms.isNotEmpty && filteredRooms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: KosMatePaginationBar(
              currentPage: paged.safePage,
              totalPages: paged.totalPages,
              totalItems: filteredRooms.length,
              startIndex: paged.startIndex,
              endIndex: paged.endIndex,
              pageSize: _roomPageSize,
              onPageChanged: (p) => setState(() => _roomPage = p),
              onPageSizeChanged: (s) => setState(() {
                _roomPageSize = s;
                _roomPage = 1;
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildRoomTile({required RoomModel room, String? tenantName}) {
    final (Color badgeBg, Color badgeText) = switch (room.status) {
      RoomStatus.available => (AppTheme.successLight, AppTheme.successColor),
      RoomStatus.occupied => (AppTheme.primaryLight, AppTheme.primaryColor),
      RoomStatus.maintenance => (
        AppTheme.destructiveLight,
        AppTheme.destructiveColor,
      ),
      RoomStatus.unavailable => (AppTheme.surfaceLight, AppTheme.textMuted),
    };

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
          onTap: () => _handleRoomTap(room),
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
                        ? ZoomableImage(
                            imageProvider: NetworkImage(room.imageUrls.first),
                            child: Image.network(
                              room.imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.meeting_room_outlined,
                                color: AppTheme.accentColor,
                              ),
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
                          Flexible(
                            child: Text(
                              '${Formatters.formatCurrency(room.price)} / mo',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (tenantName != null)
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    size: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      tenantName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) {
                    if (val == 'details') {
                      _handleRoomTap(room);
                    } else if (val == 'edit') {
                      _handleEditRoom(room);
                    } else if (val == 'delete') {
                      _deleteRoom(room);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (widget.onRoomTap != null)
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 18,
                              color: AppTheme.accentColor,
                            ),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
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
                          Text('Edit Room'),
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
                            'Delete Room',
                            style: TextStyle(color: AppTheme.destructiveColor),
                          ),
                        ],
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
