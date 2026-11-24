import 'package:flutter/material.dart';

import '../../../core/constants/room_facilities.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../core/widgets/room_facilities_selector.dart';
import '../../../models/house_model.dart';
import '../../../models/room_model.dart';

class AdminRoomFormScreen extends StatefulWidget {
  final RoomModel? room;
  final int? initialHouseId;

  const AdminRoomFormScreen({super.key, this.room, this.initialHouseId});

  bool get isEditing => room != null;

  @override
  State<AdminRoomFormScreen> createState() => _AdminRoomFormScreenState();
}

class _AdminRoomFormScreenState extends State<AdminRoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomService = sl.room;
  final _houseService = sl.house;

  late final TextEditingController _roomNumberController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageUrlController;

  int? _selectedHouseId;
  String _selectedRoomType = 'Standard';
  RoomStatus _selectedStatus = RoomStatus.available;
  late List<String> _selectedFacilities;

  List<HouseModel> _houses = [];
  bool _isLoadingHouses = true;
  bool _isSaving = false;

  final List<String> _roomTypeOptions = [
    'Standard',
    'Deluxe',
    'VIP',
    'Studio',
    'Floor 1',
    'Floor 2',
    'Floor 3',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    _roomNumberController = TextEditingController(text: r?.roomNumber ?? '');
    _priceController = TextEditingController(
      text: r != null ? r.price.toStringAsFixed(0) : '',
    );
    _selectedFacilities = RoomFacilities.parse(r?.facilities);
    _imageUrlController = TextEditingController(
      text: r?.imageUrls.isNotEmpty == true ? r!.imageUrls.first : '',
    );
    _selectedHouseId = r?.houseId ?? widget.initialHouseId;
    _selectedStatus = r?.status ?? RoomStatus.available;

    if (r != null && r.roomType.isNotEmpty) {
      if (!_roomTypeOptions.contains(r.roomType)) {
        _roomTypeOptions.insert(0, r.roomType);
      }
      _selectedRoomType = r.roomType;
    }

    _loadHouses();
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadHouses() async {
    try {
      final houses = await _houseService.getAllHouses();
      if (mounted) {
        setState(() {
          _houses = houses;
          if (_selectedHouseId == null && houses.isNotEmpty) {
            _selectedHouseId = houses.first.houseId;
          }
          _isLoadingHouses = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHouses = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a boarding house.')),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final img = _imageUrlController.text.trim();
      final List<String> imageUrls = img.isNotEmpty ? [img] : [];

      if (widget.isEditing) {
        final updated = widget.room!.copyWith(
          houseId: _selectedHouseId!,
          roomNumber: _roomNumberController.text.trim(),
          roomType: _selectedRoomType,
          price: price,
          status: _selectedStatus,
          facilities: _selectedFacilities.join(', '),
          imageUrls: imageUrls,
        );
        await _roomService.updateRoom(updated);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Room updated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        final newRoom = RoomModel(
          roomId: 0,
          houseId: _selectedHouseId!,
          roomNumber: _roomNumberController.text.trim(),
          roomType: _selectedRoomType,
          price: price,
          status: _selectedStatus,
          facilities: _selectedFacilities.join(', '),
          imageUrls: imageUrls,
          createdAt: DateTime.now(),
        );
        await _roomService.createRoom(newRoom);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Room created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save room: $e'),
          backgroundColor: AppTheme.destructiveColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete() async {
    if (!widget.isEditing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text(
          'Are you sure you want to delete Room "${widget.room!.roomNumber}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructiveColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _roomService.deleteRoom(widget.room!.roomId);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Room deleted successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete room: $e'),
          backgroundColor: AppTheme.destructiveColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KosMateAppBar(
        title: widget.isEditing ? 'Edit Room' : 'Add Room',
        showBackButton: true,
      ),
      body: _isLoadingHouses
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Room Details',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Admin can inspect and configure all room parameters.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Room number *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _roomNumberController,
                      decoration: InputDecoration(
                        hintText: 'e.g. C-02 or 101',
                        prefixIcon: const Icon(
                          Icons.meeting_room_outlined,
                          color: AppTheme.textMuted,
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
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Room number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Boarding house *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _selectedHouseId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.apartment_outlined,
                          color: AppTheme.textMuted,
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
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _houses.map((h) {
                        final ownerName =
                            h.owner?.name ?? 'Owner #${h.ownerId}';
                        return DropdownMenuItem<int>(
                          value: h.houseId,
                          child: Text(
                            '${h.houseName} ($ownerName)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedHouseId = val),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Room type *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedRoomType,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.category_outlined,
                          color: AppTheme.textMuted,
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
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: _roomTypeOptions.map((t) {
                        return DropdownMenuItem<String>(
                          value: t,
                          child: Text(t),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedRoomType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Price / month (Rp) *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 800000',
                        prefixIcon: const Icon(
                          Icons.payments_outlined,
                          color: AppTheme.textMuted,
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
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Price is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Facilities',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RoomFacilitiesSelector(
                      selectedFacilities: _selectedFacilities,
                      onChanged: (facilities) {
                        setState(() => _selectedFacilities = facilities);
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Status *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<RoomStatus>(
                      value: _selectedStatus,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.flag_outlined,
                          color: AppTheme.textMuted,
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
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: RoomStatus.values.map((s) {
                        return DropdownMenuItem<RoomStatus>(
                          value: s,
                          child: Text(s.displayName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Photo URL (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        prefixIcon: const Icon(
                          Icons.image_outlined,
                          color: AppTheme.textMuted,
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
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    if (_imageUrlController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _imageUrlController.text.trim(),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 60,
                            color: AppTheme.surfaceLight,
                            child: const Center(
                              child: Text(
                                'Invalid image URL preview',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    widget.isEditing
                                        ? 'Save Changes'
                                        : 'Save Room',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    if (widget.isEditing) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _handleDelete,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.destructiveColor,
                          ),
                          label: const Text(
                            'Delete Room',
                            style: TextStyle(
                              color: AppTheme.destructiveColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppTheme.destructiveColor,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
