import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/house_model.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../services/house_service.dart';
import '../../services/room_service.dart';
import 'house_form_screen.dart';

class HouseDetailScreen extends StatefulWidget {
  final HouseModel house;
  final UserModel currentUser;

  const HouseDetailScreen({
    super.key,
    required this.house,
    required this.currentUser,
  });

  @override
  State<HouseDetailScreen> createState() => _HouseDetailScreenState();
}

class _HouseDetailScreenState extends State<HouseDetailScreen> {
  late HouseModel _house;
  final _houseService = HouseService();
  final _roomService = RoomService();

  List<RoomModel> _rooms = [];
  bool _isLoading = true;

  bool get _canManage =>
      widget.currentUser.role == UserRole.admin ||
      widget.currentUser.userId == _house.ownerId;

  @override
  void initState() {
    super.initState();
    _house = widget.house;
    _loadHouseData();
  }

  Future<void> _loadHouseData() async {
    setState(() => _isLoading = true);
    try {
      final rooms = await _roomService.getRooms(houseId: _house.houseId);
      final refreshed = await _houseService.getHouseById(_house.houseId);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          if (refreshed != null) _house = refreshed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEditHouse() async {
    final updated = await Navigator.push<HouseModel>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseFormScreen(house: _house, ownerId: _house.ownerId),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _house = updated);
      _loadHouseData();
    }
  }

  Future<void> _handleDeleteHouse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Boarding House'),
        content: Text(
          'Are you sure you want to delete "${_house.houseName}"?\n\n'
          'All associated rooms and records will also be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB33A3A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _houseService.deleteHouse(_house.houseId);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Boarding house deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete house: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAddRoomDialog() {
    final numberCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final facilitiesCtrl = TextEditingController();
    RoomStatus selectedStatus = RoomStatus.available;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Room to ${_house.houseName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room Number *',
                    hintText: 'e.g. A-01, 102',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room Type *',
                    hintText: 'e.g. Deluxe, Standard, Single',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly Price (IDR) *',
                    hintText: 'e.g. 1500000',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: facilitiesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Facilities (optional)',
                    hintText: 'AC, WiFi, Kasur, Kamar Mandi Dalam',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoomStatus>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Initial Status',
                  ),
                  items: RoomStatus.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStatus = val);
                  },
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
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (numberCtrl.text.trim().isEmpty ||
                          typeCtrl.text.trim().isEmpty ||
                          priceCtrl.text.trim().isEmpty) {
                        return;
                      }

                      final parsedPrice =
                          double.tryParse(priceCtrl.text.trim()) ?? 0;
                      setDialogState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);

                      try {
                        await _roomService.createRoom(
                          RoomModel(
                            roomId: 0,
                            houseId: _house.houseId,
                            roomNumber: numberCtrl.text.trim(),
                            roomType: typeCtrl.text.trim(),
                            price: parsedPrice,
                            facilities: facilitiesCtrl.text.trim().isNotEmpty
                                ? facilitiesCtrl.text.trim()
                                : null,
                            status: selectedStatus,
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadHouseData();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Room created successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
              child: const Text(
                'Save Room',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableRooms = _rooms
        .where((r) => r.status == RoomStatus.available)
        .length;
    final occupiedRooms = _rooms
        .where((r) => r.status == RoomStatus.occupied)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _house.houseName,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.foregroundColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.foregroundColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_canManage) ...[
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AppTheme.accentColor,
              ),
              tooltip: 'Edit House',
              onPressed: _handleEditHouse,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFB33A3A)),
              tooltip: 'Delete House',
              onPressed: _handleDeleteHouse,
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHouseData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // House Image Banner
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        color: const Color(0xFFE2E8F0),
                        child:
                            _house.thumbnailUrl != null &&
                                _house.thumbnailUrl!.trim().isNotEmpty
                            ? Image.network(
                                _house.thumbnailUrl!.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _buildFallbackBanner(),
                              )
                            : _buildFallbackBanner(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // House Details Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: AppTheme.accentColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _house.houseAddress,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 15,
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_house.description != null &&
                              _house.description!.trim().isNotEmpty) ...[
                            const Divider(height: 20, color: Color(0xFFF1F5F9)),
                            Text(
                              _house.description!,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                height: 1.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                          if (_house.owner != null) ...[
                            const Divider(height: 20, color: Color(0xFFF1F5F9)),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_pin,
                                  color: Color(0xFF94A3B8),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Managed by: ${_house.owner!.name}',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Rooms Summary Statistics
                    Row(
                      children: [
                        _buildStatTile(
                          label: 'Total Rooms',
                          count: _rooms.length.toString(),
                          color: const Color(0xFFEBF3FA),
                          textColor: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 10),
                        _buildStatTile(
                          label: 'Occupied',
                          count: occupiedRooms.toString(),
                          color: const Color(0xFFFBEBEB),
                          textColor: const Color(0xFFB33A3A),
                        ),
                        const SizedBox(width: 10),
                        _buildStatTile(
                          label: 'Available',
                          count: availableRooms.toString(),
                          color: const Color(0xFFE6F4EA),
                          textColor: const Color(0xFF137333),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),

                    // Rooms Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Rooms in this House',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.foregroundColor,
                          ),
                        ),
                        if (_canManage)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Room'),
                            onPressed: _showAddRoomDialog,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Rooms List
                    if (_rooms.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(
                              Icons.meeting_room_outlined,
                              size: 48,
                              color: Color(0xFFCBD5E1),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No rooms registered yet',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _canManage
                                  ? 'Click "Add Room" above to list rooms in this house.'
                                  : 'Rooms will appear here once listed by the owner.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _rooms.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final room = _rooms[index];
                          final isAvailable =
                              room.status == RoomStatus.available;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? const Color(0xFFE6F4EA)
                                        : const Color(0xFFFBEBEB),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.bed_outlined,
                                    color: isAvailable
                                        ? const Color(0xFF137333)
                                        : const Color(0xFFB33A3A),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Room ${room.roomNumber} (${room.roomType})',
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.foregroundColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${Formatters.formatCurrency(room.price)} / month',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      if (room.facilities != null &&
                                          room.facilities!
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          room.facilities!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? const Color(0xFFE6F4EA)
                                        : const Color(0xFFFBEBEB),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    room.status.displayName,
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isAvailable
                                          ? const Color(0xFF137333)
                                          : const Color(0xFFB33A3A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work_outlined, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 8),
            Text(
              'Boarding House',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String count,
    required Color color,
    required Color textColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
