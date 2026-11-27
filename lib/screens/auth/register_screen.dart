import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../models/user_model.dart';
import 'widgets/terms_of_service_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = sl.auth;

  UserRole _selectedRole = UserRole.tenant; // Tenant = Renter
  bool _agreeTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to terms and services to proceed.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Please sign in.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Registration failed: ${e.toString()}'),
          backgroundColor: AppTheme.destructiveColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPrefixedInput({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
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
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.foregroundColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderMedium, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 48,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppTheme.borderLight, width: 1.5),
                  ),
                ),
                child: Icon(prefixIcon, color: AppTheme.textSubtle, size: 22),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  validator: validator,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    suffixIcon: suffixIcon,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRoleSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Select Your Role',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            color: AppTheme.foregroundColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose how you want to use KosMate:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                setState(() => _selectedRole = UserRole.tenant);
                Navigator.pop(ctx);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedRole == UserRole.tenant
                      ? AppTheme.primaryLight
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedRole == UserRole.tenant
                        ? AppTheme.accentColor
                        : AppTheme.borderMedium,
                    width: _selectedRole == UserRole.tenant ? 2.0 : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedRole == UserRole.tenant
                            ? AppTheme.accentColor
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.vpn_key_outlined,
                        color: _selectedRole == UserRole.tenant
                            ? Colors.white
                            : AppTheme.textMuted,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tenant',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Find, book rooms, pay rent and submit complaints.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedRole == UserRole.tenant)
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.accentColor,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                setState(() => _selectedRole = UserRole.owner);
                Navigator.pop(ctx);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _selectedRole == UserRole.owner
                      ? AppTheme.primaryLight
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedRole == UserRole.owner
                        ? AppTheme.accentColor
                        : AppTheme.borderMedium,
                    width: _selectedRole == UserRole.owner ? 2.0 : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedRole == UserRole.owner
                            ? AppTheme.accentColor
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.home_work_outlined,
                        color: _selectedRole == UserRole.owner
                            ? Colors.white
                            : AppTheme.textMuted,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Owner',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Manage boarding houses, rooms, payments and tenants.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedRole == UserRole.owner)
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.accentColor,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const KosMateAppBar(title: 'KosMate', showBackButton: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome to KosMate',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foregroundColor,
                  ),
                ),
                const SizedBox(height: 28),
                _buildPrefixedInput(
                  controller: _nameController,
                  label: 'Username',
                  prefixIcon: Icons.account_circle_outlined,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildPrefixedInput(
                  controller: _emailController,
                  label: 'E-mail',
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter email';
                    }
                    if (!val.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildPrefixedInput(
                  controller: _phoneController,
                  label: 'Phone number',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter phone number';
                    }
                    if (val.trim().length < 8) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Role',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _showRoleSelectionDialog,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.borderMedium,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.iconBadgeBackground,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                _selectedRole == UserRole.owner
                                    ? Icons.home_work_outlined
                                    : Icons.vpn_key_outlined,
                                color: AppTheme.accentColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedRole == UserRole.owner
                                        ? 'Owner'
                                        : 'Tenant',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.foregroundColor,
                                    ),
                                  ),
                                  Text(
                                    _selectedRole == UserRole.owner
                                        ? 'Manage rooms and receive rent'
                                        : 'Find room and pay monthly rent',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: AppTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPrefixedInput(
                  controller: _passwordController,
                  label: 'Password',
                  prefixIcon: Icons.vpn_key_outlined,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppTheme.textSubtle,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildPrefixedInput(
                  controller: _confirmPasswordController,
                  label: 'Password Confirmation',
                  prefixIcon: Icons.check_circle_outline_rounded,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppTheme.textSubtle,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _agreeTerms,
                        activeColor: AppTheme.accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: const BorderSide(
                          color: AppTheme.borderMedium,
                          width: 1.5,
                        ),
                        onChanged: (val) =>
                            setState(() => _agreeTerms = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'I agree to ',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        color: AppTheme.textDark,
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final agreed = await TermsOfServiceDialog.show(context);
                        if (agreed == true && mounted) {
                          setState(() => _agreeTerms = true);
                        }
                      },
                      child: const Text(
                        'terms and services.',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Already have an account?',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          color: AppTheme.textDark,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ],
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
}
