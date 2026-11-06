import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/house_model.dart';
import '../../services/house_service.dart';

class HouseFormScreen extends StatefulWidget {
  final HouseModel? house;
  final int ownerId;

  const HouseFormScreen({super.key, this.house, required this.ownerId});

  bool get isEditing => house != null;

  @override
  State<HouseFormScreen> createState() => _HouseFormScreenState();
}

class _HouseFormScreenState extends State<HouseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _thumbnailUrlController;
  final _houseService = HouseService();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.house?.houseName ?? '',
    );
    _addressController = TextEditingController(
      text: widget.house?.houseAddress ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.house?.description ?? '',
    );
    _thumbnailUrlController = TextEditingController(
      text: widget.house?.thumbnailUrl ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _thumbnailUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      HouseModel result;
      if (widget.isEditing) {
        final updatedHouse = widget.house!.copyWith(
          houseName: _nameController.text.trim(),
          houseAddress: _addressController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          thumbnailUrl: _thumbnailUrlController.text.trim().isNotEmpty
              ? _thumbnailUrlController.text.trim()
              : null,
        );
        result = await _houseService.updateHouse(updatedHouse);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Boarding house updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final newHouse = HouseModel(
          houseId: 0,
          ownerId: widget.ownerId,
          houseName: _nameController.text.trim(),
          houseAddress: _addressController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          thumbnailUrl: _thumbnailUrlController.text.trim().isNotEmpty
              ? _thumbnailUrlController.text.trim()
              : null,
        );
        result = await _houseService.createHouse(newHouse);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Boarding house added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save house: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing
        ? 'Edit Boarding House'
        : 'Add Boarding House';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          title,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Thumbnail Preview Card
              if (_thumbnailUrlController.text.trim().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Image.network(
                      _thumbnailUrlController.text.trim(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 40,
                              color: Color(0xFF94A3B8),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Unable to load image from URL',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // House Name
              _buildLabel('House Name *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a house name';
                  }
                  return null;
                },
                decoration: _inputDecoration(
                  hintText: 'e.g. Kos Melati Indah',
                  prefixIcon: Icons.home_work_outlined,
                ),
              ),
              const SizedBox(height: 18),

              // Address
              _buildLabel('House Address *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter the street address';
                  }
                  return null;
                },
                decoration: _inputDecoration(
                  hintText: 'e.g. Jl. Telekomunikasi No. 1, Bandung',
                  prefixIcon: Icons.location_on_outlined,
                ),
              ),
              const SizedBox(height: 18),

              // Description
              _buildLabel('Description (Optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _inputDecoration(
                  hintText: 'e.g. Close to campus, 24/7 security, quiet residential area...',
                  prefixIcon: Icons.notes_outlined,
                ),
              ),
              const SizedBox(height: 18),

              // Thumbnail URL
              _buildLabel('Thumbnail Image URL (Optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _thumbnailUrlController,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
                decoration: _inputDecoration(
                  hintText: 'https://example.com/house.jpg',
                  prefixIcon: Icons.image_outlined,
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _handleSave,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.isEditing
                                  ? 'Save Changes'
                                  : 'Create House',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.foregroundColor,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        borderSide: const BorderSide(color: AppTheme.accentColor, width: 1.8),
      ),
    );
  }
}
