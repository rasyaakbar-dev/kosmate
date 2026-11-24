import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
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

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _thumbnailUrlController;

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
    _thumbnailUrlController = TextEditingController(text: h?.thumbnailUrl ?? '');
    _selectedOwnerId = h?.ownerId;

    _loadOwners();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _thumbnailUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadOwners() async {
    try {
      final res = await supabase
          .from(SupabaseConstants.usersTable)
          .select()
          .eq('role', 'owner')
          .order('name');
      final owners = (res as List)
          .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
          .toList();

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
      final thumb = _thumbnailUrlController.text.trim();
      if (widget.isEditing) {
        final updated = widget.house!.copyWith(
          houseName: _nameController.text.trim(),
          ownerId: _selectedOwnerId!,
          houseAddress: _addressController.text.trim(),
          description: _descriptionController.text.trim(),
          thumbnailUrl: thumb.isNotEmpty ? thumb : null,
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
          thumbnailUrl: thumb.isNotEmpty ? thumb : null,
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

                    // House Name
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
                          borderSide: const BorderSide(color: AppTheme.borderMedium),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderMedium),
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

                    // Owner Dropdown
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
                          borderSide: const BorderSide(color: AppTheme.borderMedium),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderMedium),
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
                      onChanged: (val) => setState(() => _selectedOwnerId = val),
                    ),
                    const SizedBox(height: 16),

                    // Address
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
                          borderSide: const BorderSide(color: AppTheme.borderMedium),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderMedium),
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

                    // Description
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
                          borderSide: const BorderSide(color: AppTheme.borderMedium),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderMedium),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Thumbnail URL
                    const Text(
                      'Thumbnail URL (Photo Link)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _thumbnailUrlController,
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        prefixIcon: const Icon(
                          Icons.image_outlined,
                          color: AppTheme.textMuted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderMedium),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderMedium),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    if (_thumbnailUrlController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _thumbnailUrlController.text.trim(),
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

                    // Action Buttons
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
