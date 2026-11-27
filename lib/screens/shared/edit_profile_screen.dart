import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kosmate_components.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import 'widgets/profile_security_dialogs.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _authService = sl.auth;
  final _storageService = sl.storage;
  final _imagePicker = ImagePicker();

  Uint8List? _newAvatarBytes;
  String _newAvatarExtension = 'jpg';
  String? _currentAvatarUrl;
  bool _resetAvatar = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _currentAvatarUrl = widget.user.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          _newAvatarBytes = bytes;
          _newAvatarExtension = picked.name.split('.').last;
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

  void _showAvatarOptionsModal() {
    final hasAvatar =
        _newAvatarBytes != null ||
        (!_resetAvatar &&
            _currentAvatarUrl != null &&
            _currentAvatarUrl!.isNotEmpty);

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
                'Profile Picture',
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
              title: const Text('Take Photo'),
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
                  'Reset to Default',
                  style: TextStyle(color: AppTheme.destructiveColor),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _newAvatarBytes = null;
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
      String? finalAvatarUrl = _currentAvatarUrl;

      if (_newAvatarBytes != null) {
        finalAvatarUrl = await _storageService.uploadAvatar(
          widget.user.userId,
          _newAvatarBytes!,
          extension: _newAvatarExtension,
        );
      } else if (_resetAvatar) {
        finalAvatarUrl = null;
      }

      final updatedUser = await _authService.updateProfile(
        userId: widget.user.userId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        avatarUrl: finalAvatarUrl,
        clearAvatar: _resetAvatar,
      );
      String? cleanupWarning;
      if (_resetAvatar || _newAvatarBytes != null) {
        try {
          await _storageService.deleteAvatar(
            widget.user.userId,
            avatarUrl: _currentAvatarUrl,
          );
        } catch (e) {
          cleanupWarning =
              'Profile saved, but the previous image could not be removed: $e';
        }
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(cleanupWarning ?? 'Profile updated successfully!'),
          backgroundColor: cleanupWarning == null
              ? AppTheme.successColor
              : AppTheme.warningColor,
        ),
      );

      if (mounted) {
        Navigator.pop(context, updatedUser);
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.toLowerCase().contains('bucket not found') ||
          errorMessage.toLowerCase().contains('nosuchbucket')) {
        errorMessage = 'Storage bucket "avatars" is missing in Supabase. Please run the SQL schema or create the "avatars" bucket (Public) in Supabase Storage.';
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppTheme.destructiveColor,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showChangePasswordDialog() {
    showChangePasswordDialog(context);
  }

  void _showDeleteAccountDialog() {
    showDeleteAccountDialog(
      context,
      onConfirmed: () async {
        setState(() => _isLoading = true);
        try {
          await _authService.deleteAccount(widget.user.userId);
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to delete account: $e'),
                backgroundColor: AppTheme.destructiveColor,
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (_newAvatarBytes != null) {
      avatarImage = MemoryImage(_newAvatarBytes!);
    } else if (!_resetAvatar &&
        _currentAvatarUrl != null &&
        _currentAvatarUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_currentAvatarUrl!);
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
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
          child: Container(color: AppTheme.borderLight, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showAvatarOptionsModal,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: AppTheme.borderLight,
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? Text(
                                    widget.user.name.isNotEmpty
                                        ? widget.user.name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showAvatarOptionsModal,
                      icon: const Icon(Icons.photo_camera_outlined, size: 16),
                      label: const Text(
                        'Change Photo',
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
                'Personal Information',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foregroundColor,
                ),
              ),
              const SizedBox(height: 14),

              _buildInputField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                hint: 'Enter your full name',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Name cannot be empty';
                  }
                  if (val.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildInputField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                hint: 'e.g. 081234567890',
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Phone number cannot be empty';
                  }
                  if (val.trim().length < 8) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildReadOnlyField(
                label: 'Email Address',
                value: widget.user.email,
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),

              _buildReadOnlyField(
                label: 'Account Role',
                value: widget.user.role.displayName,
                icon: Icons.admin_panel_settings_outlined,
              ),
              const SizedBox(height: 28),

              const Text(
                'Account Security',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.foregroundColor,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage your authentication and security settings.',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 14),

              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _showChangePasswordDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.borderMedium,
                        width: 1.2,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: AppTheme.accentColor,
                          size: 22,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Password',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Update your account login password',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textSubtle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Material(
                color: AppTheme.destructiveLight,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _showDeleteAccountDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.destructiveColor.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.delete_forever_outlined,
                          color: AppTheme.destructiveColor,
                          size: 22,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Account',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.destructiveColor,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Permanently delete your profile and account',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.destructiveColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.destructiveColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),

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
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _handleSave,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.foregroundColor,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppTheme.textSubtle,
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppTheme.borderMedium,
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppTheme.borderMedium,
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppTheme.accentColor,
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.foregroundColor,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          readOnly: true,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMuted,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.textSubtle, size: 20),
            suffixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: AppTheme.textSubtle,
              size: 18,
            ),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppTheme.borderLight,
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppTheme.borderLight,
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppTheme.borderMedium,
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
