import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../models/house_model.dart';
import '../../../models/room_model.dart';

class RoomFormScreen extends StatefulWidget {
  final RoomModel? room;
  final int? houseId;
  final int ownerId;

  const RoomFormScreen({
    super.key,
    this.room,
    this.houseId,
    required this.ownerId,
  });

  bool get isEditing => room != null;

  @override
  State<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends State<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomService = sl.room;
  final _houseService = sl.house;

  late TextEditingController _nameController;
  late TextEditingController _rentController;
  late TextEditingController _facilitiesController;

  int? _selectedHouseId;
  String _selectedFloor = 'Floor 1';
  RoomStatus _selectedStatus = RoomStatus.available;

  List<HouseModel> _houses = [];
  bool _isLoading = false;
  bool _isLoadingHouses = true;

  final List<String> _floorOptions = [
    'Floor 1',
    'Floor 2',
    'Floor 3',
    'Floor 4',
    'Floor 5',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    _nameController = TextEditingController(text: r?.roomNumber ?? '');
    _rentController = TextEditingController(
      text: r != null ? r.price.toStringAsFixed(0) : '',
    );
    _facilitiesController = TextEditingController(text: r?.facilities ?? '');
    _selectedStatus = r?.status ?? RoomStatus.available;
    _selectedHouseId = r?.houseId ?? widget.houseId;

    if (r != null && r.roomType.isNotEmpty) {
      if (_floorOptions.contains(r.roomType)) {
        _selectedFloor = r.roomType;
      }
    }

    _loadHouses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rentController.dispose();
    _facilitiesController.dispose();
    super.dispose();
  }

  Future<void> _loadHouses() async {
    try {
      final houses = await _houseService.getHousesByOwner(widget.ownerId);
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
      if (mounted) {
        setState(() => _isLoadingHouses = false);
      }
    }
  }

  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a boarding house first.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final rentValue = double.tryParse(_rentController.text.trim()) ?? 0.0;
      final roomData = RoomModel(
        roomId: widget.room?.roomId ?? 0,
        houseId: _selectedHouseId!,
        roomNumber: _nameController.text.trim(),
        roomType: _selectedFloor,
        price: rentValue,
        facilities: _facilitiesController.text.trim().isNotEmpty
            ? _facilitiesController.text.trim()
            : null,
        status: _selectedStatus,
      );

      RoomModel saved;
      if (widget.isEditing) {
        saved = await _roomService.updateRoom(roomData);
      } else {
        saved = await _roomService.createRoom(roomData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Room updated successfully!'
                  : 'Room created successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save room: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Edit room' : 'Add room';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: KosMateAppBar(
        title: title,
        showBackButton: true,
        showLogo: false,
        showHelp: false,
      ),
      body: _isLoadingHouses
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 20.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Boarding house dropdown if multiple available
                      if (_houses.length > 1) ...[
                        const Text(
                          'Boarding house',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedHouseId,
                          decoration: _inputDecoration(
                            prefixIcon: Icons.apartment_outlined,
                          ),
                          items: _houses
                              .map(
                                (h) => DropdownMenuItem(
                                  value: h.houseId,
                                  child: Text(h.houseName),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedHouseId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Room Name
                      const Text(
                        'Room name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration(
                          hintText: 'Room C-01',
                          prefixIcon: Icons.meeting_room_outlined,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter room name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Floor
                      const Text(
                        'Floor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedFloor,
                        decoration: _inputDecoration(),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.accentColor,
                        ),
                        items: _floorOptions
                            .map(
                              (floor) => DropdownMenuItem(
                                value: floor,
                                child: Text(floor),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedFloor = val);
                          }
                        },
                      ),
                      const SizedBox(height: 18),

                      // Monthly Rent
                      const Text(
                        'Monthly rent',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _rentController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          hintText: '750000',
                          prefixIcon: Icons.payments_outlined,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter monthly rent';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Status
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<RoomStatus>(
                        initialValue: _selectedStatus,
                        decoration: _inputDecoration(),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.accentColor,
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
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                          }
                        },
                      ),
                      const SizedBox(height: 18),

                      // Facilities
                      const Text(
                        'Facilities',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _facilitiesController,
                        maxLines: 4,
                        decoration: _inputDecoration(
                          hintText: 'Bed, desk, private bathroom',
                          prefixIcon: Icons.playlist_add_check_outlined,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Buttons Row: Cancel and Save room
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentColor,
                                side: const BorderSide(
                                  color: AppTheme.accentColor,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Cancel',
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
                              onPressed: _isLoading ? null : _saveRoom,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: _isLoading
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
                                          ? 'Update room'
                                          : 'Save room',
                                      style: const TextStyle(
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
              ),
            ),
    );
  }

  InputDecoration _inputDecoration({String? hintText, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 20)
          : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.accentColor, width: 1.5),
      ),
    );
  }
}
