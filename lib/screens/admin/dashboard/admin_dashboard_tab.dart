import 'package:flutter/material.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/house_model.dart';
import '../../../models/user_model.dart';
import '../houses/admin_house_form_screen.dart';
import '../payments/admin_payments_screen.dart';
import '../users/admin_user_detail_screen.dart';

class AdminDashboardTab extends StatefulWidget {
  final UserModel user;
  final Function(int) onNavigateToTab;

  const AdminDashboardTab({
    super.key,
    required this.user,
    required this.onNavigateToTab,
  });

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  int _userCount = 0;
  int _houseCount = 0;
  List<UserModel> _recentUsers = [];
  List<HouseModel> _recentHouses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    try {
      final usersRes = await supabase
          .from(SupabaseConstants.usersTable)
          .select();
      final housesRes = await sl.house.getAllHouses();

      final usersList = (usersRes as List)
          .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _userCount = usersList.length;
          _houseCount = housesRes.length;
          _recentUsers = usersList;
          _recentHouses = housesRes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openPaymentsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminPaymentsScreen()),
    ).then((_) {
      if (mounted) _loadAdminData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadAdminData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${widget.user.name.isNotEmpty ? widget.user.name : "User"}',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'System administrator',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => widget.onNavigateToTab(1),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Users',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                Icon(
                                  Icons.group_outlined,
                                  color: AppTheme.accentColor,
                                  size: 22,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$_userCount',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Material(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => widget.onNavigateToTab(2),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.warningLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Houses',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 14,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                Icon(
                                  Icons.apartment_outlined,
                                  color: AppTheme.accentColor,
                                  size: 22,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$_houseCount',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Quick actions',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                _buildQuickActionTile(
                  icon: Icons.group_outlined,
                  label: 'Users',
                  onTap: () => widget.onNavigateToTab(1),
                ),
                const SizedBox(width: 12),
                _buildQuickActionTile(
                  icon: Icons.apartment_outlined,
                  label: 'Houses',
                  onTap: () => widget.onNavigateToTab(2),
                ),
                const SizedBox(width: 12),
                _buildQuickActionTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Payments',
                  onTap: _openPaymentsScreen,
                ),
              ],
            ),
            const SizedBox(height: 26),

            const Text(
              'Recent activity',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.foregroundColor,
              ),
            ),
            const SizedBox(height: 12),

            if (_recentUsers.isNotEmpty) ...[
              _buildActivityCard(
                icon: Icons.person_outline,
                title: 'User registered',
                subtitle:
                    '${_recentUsers.first.name} • ${_recentUsers.first.role.name.toUpperCase()}',
                trailingText: Formatters.formatDate(
                  _recentUsers.first.createdAt,
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminUserDetailScreen(user: _recentUsers.first),
                    ),
                  );
                  if (mounted) _loadAdminData();
                },
              ),
              const SizedBox(height: 10),
            ],

            if (_recentHouses.isNotEmpty) ...[
              _buildActivityCard(
                icon: Icons.apartment_outlined,
                title: 'Boarding house added',
                subtitle:
                    '${_recentHouses.first.houseName} • ${_recentHouses.first.houseAddress}',
                trailingText: Formatters.formatDate(
                  _recentHouses.first.createdAt,
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminHouseFormScreen(house: _recentHouses.first),
                    ),
                  );
                  if (mounted) _loadAdminData();
                },
              ),
            ] else if (_recentUsers.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No recent activities yet.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderMedium, width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.accentColor, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailingText,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.iconBadgeBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trailingText,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSubtle,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
