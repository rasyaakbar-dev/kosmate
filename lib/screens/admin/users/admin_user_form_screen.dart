import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/kosmate_app_bar.dart';
import '../../../core/widgets/kosmate_components.dart';
import '../../../models/user_model.dart';

class AdminUserFormScreen extends StatefulWidget {
  final UserModel? user;

  const AdminUserFormScreen({super.key, this.user});

  bool get isEditing => user != null;

  @override
  State<AdminUserFormScreen> createState() => _AdminUserFormScreenState();
}

class _AdminUserFormScreenState extends State<AdminUserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = sl.user;
  final _storageService = sl.storage;
  final _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _phoneController;
  late UserRole _selectedRole;

  Uint8List? _selectedAvatarBytes;
  String _selectedAvatarExtension = 'jpg';
  String? _currentAvatarUrl;
  bool _resetAvatar = false;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameController = TextEditingController(text: u?.name ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _passwordController = TextEditingController();
    _phoneController = TextEditingController(text: u?.phone ?? '');
    _selectedRole = u?.role ?? UserRole.tenant;
    _currentAvatarUrl = u?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedAvatarBytes = bytes;
          _selectedAvatarExtension = picked.name.split('.').last;
          _resetAvatar = false;
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

  void _showAvatarSourceModal() {
    final hasAvatar =
        _selectedAvatarBytes != null ||
        (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty);

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
                'Change Profile Photo',
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
                Icons.camera_alt_outlined,
                color: AppTheme.accentColor,
              ),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppTheme.accentColor,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.destructiveColor,
                ),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: AppTheme.destructiveColor),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedAvatarBytes = null;
                    _currentAvatarUrl = null;
                    _resetAvatar = true;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (widget.isEditing) {
        String? finalAvatarUrl = _currentAvatarUrl;

        if (_selectedAvatarBytes != null) {
          finalAvatarUrl = await _storageService.uploadAvatar(
            widget.user!.userId,
            _selectedAvatarBytes!,
            extension: _selectedAvatarExtension,
          );
        } else if (_resetAvatar) {
          finalAvatarUrl = '';
        }

        await _userService.updateUser(
          userId: widget.user!.userId,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole,
          avatarUrl: finalAvatarUrl,
        );
        String? cleanupWarning;
        if (_resetAvatar || _selectedAvatarBytes != null) {
          try {
            await _storageService.deleteAvatar(
              widget.user!.userId,
              avatarUrl: _currentAvatarUrl,
            );
          } catch (e) {
            cleanupWarning =
                'User saved, but the previous image could not be removed: $e';
          }
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              cleanupWarning ?? 'User profile updated successfully!',
            ),
            backgroundColor: cleanupWarning == null
                ? AppTheme.successColor
                : AppTheme.warningColor,
          ),
        );
      } else {
        await _userService.createUser(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phone: _phoneController.text.trim(),
          role: _selectedRole,
        );

        if (_selectedAvatarBytes != null) {
          try {
            final createdUser = await _userService.getUserByEmail(
              _emailController.text.trim(),
            );
            if (createdUser != null) {
              final uploadedUrl = await _storageService.uploadAvatar(
                createdUser.userId,
                _selectedAvatarBytes!,
                extension: _selectedAvatarExtension,
              );
              await _userService.updateAvatarUrl(
                userId: createdUser.userId,
                avatarUrl: uploadedUrl,
              );
            }
          } catch (_) {}
        }

        messenger.showSnackBar(
          const SnackBar(
            content: Text('User created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save user: $e'),
          backgroundColor: AppTheme.destructiveColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    if (!widget.isEditing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text(
          'Are you sure you want to permanently delete user "${widget.user!.name}" (${widget.user!.email})?\n\nThis will remove all associated user data.',
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

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _userService.deleteUser(widget.user!.userId);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('User deleted successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete user: $e'),
          backgroundColor: AppTheme.destructiveColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (_selectedAvatarBytes != null) {
      avatarImage = MemoryImage(_selectedAvatarBytes!);
    } else if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_currentAvatarUrl!);
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: KosMateAppBar(
        title: widget.isEditing ? 'Edit User' : 'Add User',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primaryLight,
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? Text(
                                  _nameController.text.trim().isNotEmpty
                                      ? _nameController.text
                                            .trim()[0]
                                            .toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showAvatarSourceModal,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _showAvatarSourceModal,
                      icon: const Icon(
                        Icons.photo_camera_outlined,
                        size: 16,
                        color: AppTheme.accentColor,
                      ),
                      label: const Text(
                        'Change Profile Picture',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'User information',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foregroundColor,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter the user contact details and assign an account role.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 18),

              const Text(
                'Full name *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. John Doe',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              const Text(
                'Email address *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                readOnly: widget.isEditing,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'user@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: widget.isEditing
                      ? const Icon(
                          Icons.lock_outline,
                          color: AppTheme.textMuted,
                          size: 18,
                        )
                      : null,
                  filled: true,
                  fillColor: widget.isEditing ? AppTheme.surfaceLight : null,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Invalid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const Text(
                'Phone number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'e.g. 081234567890',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),

              if (!widget.isEditing) ...[
                const Text(
                  'Initial password *',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Min. 6 characters',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              const Text(
                'Account role *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildRoleChip('Tenant', UserRole.tenant),
                  _buildRoleChip('Owner', UserRole.owner),
                  _buildRoleChip('Admin', UserRole.admin),
                ],
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: KosMateCancelButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: KosMateButton.primary(
                      label: widget.isEditing ? 'Save Changes' : 'Create User',
                      icon: Icons.save_outlined,
                      onPressed: _handleSave,
                      isLoading: _isLoading,
                    ),
                  ),
                ],
              ),

              if (widget.isEditing) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.destructiveColor,
                    ),
                    label: const Text(
                      'Delete User',
                      style: TextStyle(
                        color: AppTheme.destructiveColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.destructiveColor),
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

  Widget _buildRoleChip(String label, UserRole role) {
    final isSelected = _selectedRole == role;
    return ChoiceChip(
      label: Center(child: Text(label)),
      selected: isSelected,
      showCheckmark: false,
      checkmarkColor: AppTheme.accentColor,
      selectedColor: AppTheme.primaryLight,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.accentColor : AppTheme.borderMedium,
        width: isSelected ? 1.5 : 1.0,
      ),
      labelStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppTheme.accentColor : AppTheme.textDark,
      ),
      onSelected: (_) => setState(() => _selectedRole = role),
    );
  }
}
