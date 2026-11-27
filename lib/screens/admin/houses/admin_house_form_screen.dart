import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/house_model.dart';
import '../../../models/user_model.dart';

class AdminHouseFormScreen extends StatefulWidget {
  final HouseModel? house;

  const AdminHouseFormScreen({super.key, this.house});

  bool get isEditing => house != null;

  @override
  State<AdminHouseFormScreen> createState() => _AdminHouseFormScreenState();
}

class _AdminHouseFormScreenState extends State<AdminHouseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _houseService = sl.house;
  final _storageService = sl.storage;
  final _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;

  Uint8List? _selectedImageBytes;
  String _selectedImageExtension = 'jpg';
  String? _currentThumbnailUrl;

  int? _selectedOwnerId;
  List<UserModel> _owners = [];
  bool _isLoadingOwners = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final h = widget.house;
    _nameController = TextEditingController(text: h?.houseName ?? '');
    _addressController = TextEditingController(text: h?.houseAddress ?? '');
    _descriptionController = TextEditingController(text: h?.description ?? '');
    _currentThumbnailUrl = h?.thumbnailUrl;
    _selectedOwnerId = h?.ownerId;

    _loadOwners();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageExtension = picked.name.split('.').last;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppTheme.destructiveColor,
          ),
        );
      }
    }
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Upload House Photo',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foregroundColor,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppTheme.primaryColor,
              ),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppTheme.primaryColor,
              ),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_selectedImageBytes != null ||
                (_currentThumbnailUrl != null &&
                    _currentThumbnailUrl!.isNotEmpty))
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.destructiveColor,
                ),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: AppTheme.destructiveColor),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedImageBytes = null;
                    _currentThumbnailUrl = null;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _loadOwners() async {
    try {
      final owners = await sl.user.getAllUsers(roleFilter: UserRole.owner);
      owners.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (mounted) {
        setState(() {
          _owners = owners;
          if (_selectedOwnerId == null && owners.isNotEmpty) {
            _selectedOwnerId = owners.first.userId;
          }
          _isLoadingOwners = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOwners = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOwnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an owner for this house.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      String? thumb = _currentThumbnailUrl;
      if (_selectedImageBytes != null) {
        thumb = await _storageService.uploadHouseImage(
          widget.house?.houseId,
          _selectedImageBytes!,
          extension: _selectedImageExtension,
        );
      }

      if (widget.isEditing) {
        final updated = widget.house!.copyWith(
          houseName: _nameController.text.trim(),
          ownerId: _selectedOwnerId!,
          houseAddress: _addressController.text.trim(),
          description: _descriptionController.text.trim(),
          thumbnailUrl: thumb != null && thumb.isNotEmpty ? thumb : null,
        );
        await _houseService.updateHouse(updated);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('House updated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        final newHouse = HouseModel(
          houseId: 0,
          ownerId: _selectedOwnerId!,
          houseName: _nameController.text.trim(),
          houseAddress: _addressController.text.trim(),
          description: _descriptionController.text.trim(),
          thumbnailUrl: thumb != null && thumb.isNotEmpty ? thumb : null,
          createdAt: DateTime.now(),
        );
        await _houseService.createHouse(newHouse);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('House created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save house: $e'),
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
        title: const Text('Delete Boarding House'),
        content: Text(
          'Are you sure you want to delete "${widget.house!.houseName}"? All rooms inside will be permanently deleted.',
        ),
        actions: [
          KosMateCancelButton(
            isOutlined: false,
            onPressed: () => Navigator.pop(ctx, false),
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
      await _houseService.deleteHouse(widget.house!.houseId);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('House deleted successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete house: $e'),
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
        title: widget.isEditing ? 'Edit House' : 'Add House',
        showBackButton: true,
      ),
      body: _isLoadingOwners
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'House information',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enter the boarding house details and assign an owner.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'House name *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Kost Melati',
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
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'House name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Owner *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _selectedOwnerId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.person_outline,
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
                      items: _owners.map((o) {
                        return DropdownMenuItem<int>(
                          value: o.userId,
                          child: Text(
                            '${o.name} (${o.email})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedOwnerId = val),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Address *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter boarding house address',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: AppTheme.textMuted,
                          ),
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
                          return 'Address is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Write a short description',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(
                            Icons.notes_outlined,
                            color: AppTheme.textMuted,
                          ),
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
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'House Photo (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _showImageSourceModal,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderMedium),
                        ),
                        child: _selectedImageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.memory(
                                  _selectedImageBytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            : (_currentThumbnailUrl != null &&
                                  _currentThumbnailUrl!.trim().isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.network(
                                  _currentThumbnailUrl!.trim(),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 36,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 32,
                                    color: AppTheme.accentColor,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tap to upload house photo',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    Row(
                      children: [
                        Expanded(
                          child: KosMateCancelButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
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
                                        : 'Save House',
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
                            'Delete House',
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
