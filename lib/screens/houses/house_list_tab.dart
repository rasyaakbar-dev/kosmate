import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/house_model.dart';
import '../../models/user_model.dart';
import '../../services/house_service.dart';
import 'house_detail_screen.dart';
import 'house_form_screen.dart';
import 'widgets/house_card.dart';

class HouseListTab extends StatefulWidget {
  final UserModel currentUser;
  final int? filterOwnerId;

  const HouseListTab({
    super.key,
    required this.currentUser,
    this.filterOwnerId,
  });

  bool get isOwnerMode => filterOwnerId != null;

  @override
  State<HouseListTab> createState() => _HouseListTabState();
}

class _HouseListTabState extends State<HouseListTab> {
  final _houseService = HouseService();
  final _searchController = TextEditingController();

  late Future<List<HouseModel>> _housesFuture;

  @override
  void initState() {
    super.initState();
    _loadHouses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadHouses() {
    setState(() {
      final baseFuture = widget.isOwnerMode
          ? _houseService.getHousesByOwner(widget.filterOwnerId!)
          : _houseService.getAllHouses();

      final term = _searchController.text.trim().toLowerCase();
      if (term.isEmpty) {
        _housesFuture = baseFuture;
      } else {
        _housesFuture = baseFuture.then(
          (houses) => houses.where((h) {
            final nameMatch = h.houseName.toLowerCase().contains(term);
            final addressMatch = h.houseAddress.toLowerCase().contains(term);
            final ownerMatch =
                h.owner?.name.toLowerCase().contains(term) ?? false;
            return nameMatch || addressMatch || ownerMatch;
          }).toList(),
        );
      }
    });
  }

  Future<void> _openAddHouseScreen() async {
    final created = await Navigator.push<HouseModel>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseFormScreen(
          ownerId: widget.filterOwnerId ?? widget.currentUser.userId,
        ),
      ),
    );
    if (created != null && mounted) {
      _loadHouses();
    }
  }

  Future<void> _openHouseDetails(HouseModel house) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            HouseDetailScreen(house: house, currentUser: widget.currentUser),
      ),
    );
    if (changed == true && mounted) {
      _loadHouses();
    }
  }

  Future<void> _openEditHouse(HouseModel house) async {
    final updated = await Navigator.push<HouseModel>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseFormScreen(house: house, ownerId: house.ownerId),
      ),
    );
    if (updated != null && mounted) {
      _loadHouses();
    }
  }

  Future<void> _confirmDeleteHouse(HouseModel house) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Boarding House'),
        content: Text(
          'Are you sure you want to delete "${house.houseName}"?\n\n'
          'All associated rooms and records will be permanently removed.',
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
        await _houseService.deleteHouse(house.houseId);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Boarding house deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadHouses();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isOwnerMode
        ? 'Boarding Houses & Rooms'
        : 'Registered Boarding Houses';

    return Column(
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foregroundColor,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add House'),
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
                onPressed: _openAddHouseScreen,
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => _loadHouses(),
            decoration: InputDecoration(
              hintText: 'Search houses by name or location...',
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
                        _loadHouses();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
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
        ),
        const SizedBox(height: 10),

        // Houses List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadHouses(),
            child: FutureBuilder<List<HouseModel>>(
              future: _housesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final houses = snapshot.data ?? [];
                if (houses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isOwnerMode
                                ? Icons.home_work_outlined
                                : Icons.apartment_outlined,
                            size: 60,
                            color: const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.isOwnerMode
                                ? 'No boarding houses listed yet.'
                                : 'No boarding houses registered.',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.isOwnerMode
                                ? 'Click "Add House" above to list your first boarding house.'
                                : 'Registered houses will appear here.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  itemCount: houses.length,
                  itemBuilder: (context, index) {
                    final house = houses[index];
                    return HouseCard(
                      house: house,
                      showOwnerInfo: !widget.isOwnerMode,
                      onTap: () => _openHouseDetails(house),
                      onEdit: () => _openEditHouse(house),
                      onDelete: () => _confirmDeleteHouse(house),
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
