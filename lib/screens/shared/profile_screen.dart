import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kosmate_components.dart';
import '../../models/user_model.dart';
// import '../debug/midtrans_debug_screen.dart';
import 'auth_gate.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final String? subtitleInfo;

  const ProfileScreen({super.key, required this.user, this.subtitleInfo});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _currentUser;
  final _authService = sl.auth;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  Future<void> _loadProfile() async {
    try {
      final fresh = await _authService.getCurrentUserProfile();
      if (fresh != null && mounted) {
        setState(() => _currentUser = fresh);
      }
    } catch (_) {}
  }

  Future<void> _openEditProfileScreen() async {
    final updated = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _currentUser)),
    );
    if (updated != null && mounted) {
      setState(() => _currentUser = updated);
    }
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.destructiveColor,
            ),
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
          MaterialPageRoute(builder: (_) => const AuthGate()),
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
          subtitle = 'Owner';
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

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: AppTheme.primaryLight,
              backgroundImage:
                  _currentUser.avatarUrl != null &&
                      _currentUser.avatarUrl!.isNotEmpty
                  ? NetworkImage(_currentUser.avatarUrl!)
                  : null,
              child:
                  _currentUser.avatarUrl == null ||
                      _currentUser.avatarUrl!.isEmpty
                  ? const Icon(
                      Icons.person_outline_rounded,
                      size: 52,
                      color: AppTheme.accentColor,
                    )
                  : null,
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
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),

            // User Information Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderMedium, width: 1.2),
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
                  _buildInfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Username',
                    value: username,
                  ),
                  const Divider(height: 22, color: AppTheme.surfaceLight),
                  _buildInfoRow(
                    icon: Icons.email_outlined,
                    label: 'E-mail',
                    value: _currentUser.email,
                  ),
                  const Divider(height: 22, color: AppTheme.surfaceLight),
                  _buildInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: phone,
                  ),
                  const Divider(height: 22, color: AppTheme.surfaceLight),
                  _buildInfoRow(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Role',
                    value: _currentUser.role.displayName,
                    isBadge: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            KosMateButton.outlined(
              label: 'Edit profile',
              icon: Icons.edit_outlined,
              onPressed: _openEditProfileScreen,
            ),
            // const SizedBox(height: 12),
            // KosMateButton.outlined(
            //   label: 'Midtrans Sandbox Debugger',
            //   icon: Icons.developer_mode_rounded,
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (_) =>
            //             MidtransDebugScreen(currentUser: _currentUser),
            //       ),
            //     );
            //   },
            // ),
            const SizedBox(height: 12),
            KosMateButton.destructive(
              label: 'Logout',
              icon: Icons.exit_to_app_rounded,
              onPressed: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isBadge = false,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.iconBadgeBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              if (isBadge)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                )
              else
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foregroundColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
