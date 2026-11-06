import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/user_service.dart';

class UserFormDialog extends StatefulWidget {
  final UserModel? user;

  const UserFormDialog({super.key, this.user});

  bool get isEditing => user != null;

  static Future<bool?> show(BuildContext context, {UserModel? user}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UserFormDialog(user: user),
    );
  }

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _phoneController;
  late UserRole _selectedRole;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController = TextEditingController();
    _phoneController = TextEditingController(text: widget.user?.phone ?? '');
    _selectedRole = widget.user?.role ?? UserRole.tenant;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (widget.isEditing) {
        await _userService.updateUser(
          userId: widget.user!.userId,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole,
        );
        messenger.showSnackBar(
          const SnackBar(
            content: Text('User updated successfully!'),
            backgroundColor: Colors.green,
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
        messenger.showSnackBar(
          const SnackBar(
            content: Text('User created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save user: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Edit User' : 'Add New User';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.foregroundColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),

                  // Full Name
                  _buildLabel('Full Name *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty)
                        return 'Please enter a name';
                      return null;
                    },
                    decoration: _inputDecoration(
                      hintText: 'e.g. John Doe',
                      prefixIcon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email
                  _buildLabel('Email Address *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    readOnly: widget.isEditing,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty)
                        return 'Please enter an email';
                      if (!val.contains('@') || !val.contains('.'))
                        return 'Invalid email address';
                      return null;
                    },
                    decoration: _inputDecoration(
                      hintText: 'user@example.com',
                      prefixIcon: Icons.email_outlined,
                      suffixText: widget.isEditing ? '(Read-only)' : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password (Only required if creating)
                  if (!widget.isEditing) ...[
                    _buildLabel('Initial Password *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      validator: (val) {
                        if (val == null || val.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      decoration: _inputDecoration(
                        hintText: 'Min. 6 characters',
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF64748B),
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Phone Number
                  _buildLabel('Phone Number'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(
                      hintText: 'e.g. 081234567890',
                      prefixIcon: Icons.phone_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Role Selection
                  _buildLabel('Account Role *'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<UserRole>(
                    initialValue: _selectedRole,
                    decoration: _inputDecoration(
                      hintText: 'Select role',
                      prefixIcon: Icons.admin_panel_settings_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.tenant,
                        child: Text('Tenant / Renter'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.owner,
                        child: Text('Kos Owner'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.admin,
                        child: Text('Administrator'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
                                    : 'Create User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
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
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 20),
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
