import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kosmate_components.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final String? subtitleInfo;

  const ProfileScreen({
    super.key,
    required this.user,
    this.subtitleInfo,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _currentUser;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  void _showEditProfileModal() {
    final nameCtrl = TextEditingController(text: _currentUser.name);
    final phoneCtrl = TextEditingController(text: _currentUser.phone);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Full name input matching figma/Components.png
              const Text(
                'Full name',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.foregroundColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.person_outline, color: Color(0xFF94A3B8), size: 22),
                    ),
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Enter your full name',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Phone number input matching figma/Components.png
              const Text(
                'Phone number',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.foregroundColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.phone_outlined, color: Color(0xFF94A3B8), size: 22),
                    ),
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Enter phone number',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Save & Cancel actions
              KosMateButton.primary(
                label: 'Save changes',
                icon: Icons.check,
                isLoading: isSaving,
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  setModalState(() => isSaving = true);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final updated = await _authService.updateProfile(
                      userId: _currentUser.userId,
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    );
                    if (mounted) setState(() => _currentUser = updated);
                    if (ctx.mounted) Navigator.pop(ctx);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully!')),
                    );
                  } catch (e) {
                    setModalState(() => isSaving = false);
                    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
              const SizedBox(height: 10),
              KosMateButton.outlined(
                label: 'Cancel',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out of KosMate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB33A3A)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine subtitle according to role & room/properties
    String subtitle;
    if (widget.subtitleInfo != null && widget.subtitleInfo!.isNotEmpty) {
      subtitle = widget.subtitleInfo!;
    } else {
      switch (_currentUser.role) {
        case UserRole.tenant:
          subtitle = 'Tenant';
          break;
        case UserRole.owner:
          subtitle = 'Kos Owner';
          break;
        case UserRole.admin:
          subtitle = 'System Administrator';
          break;
      }
    }

    final username = _currentUser.name.isNotEmpty
        ? _currentUser.name.toLowerCase().replaceAll(' ', '')
        : 'user';
    final phone = _currentUser.phone.isNotEmpty ? _currentUser.phone : '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular Avatar (Light blue circle #EBF3FA with #4A6FA5 person icon)
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: Color(0xFFEBF3FA),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.person_outline_rounded,
                size: 52,
                color: AppTheme.accentColor,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // User Name
          Text(
            _currentUser.name,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.foregroundColor,
            ),
          ),
          const SizedBox(height: 4),

          // Role Subtitle
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),

          // User Information Card (figma/Profile.png)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User information',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foregroundColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(label: 'Username', value: username),
                const SizedBox(height: 14),
                _buildInfoRow(label: 'E-mail', value: _currentUser.email),
                const SizedBox(height: 14),
                _buildInfoRow(label: 'Phone', value: phone),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          KosMateButton.outlined(
            label: 'Edit profile',
            icon: Icons.edit_outlined,
            onPressed: _showEditProfileModal,
          ),
          const SizedBox(height: 12),
          KosMateButton.destructive(
            label: 'Logout',
            icon: Icons.exit_to_app_rounded,
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.foregroundColor,
            ),
          ),
        ),
      ],
    );
  }
}

