import 'package:flutter/material.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../models/user_model.dart';
import '../../models/house_model.dart';
import '../../services/house_service.dart';
import '../shared/profile_screen.dart';
import '../houses/house_form_screen.dart';
import '../houses/house_list_tab.dart';
import 'users/user_form_dialog.dart';
import 'users/user_management_tab.dart';

class AdminMainScreen extends StatefulWidget {
  final UserModel user;

  const AdminMainScreen({super.key, required this.user});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _AdminHomeDashboard(user: widget.user, onNavigateToTab: _navigateToTab),
      UserManagementTab(currentUser: widget.user),
      HouseListTab(currentUser: widget.user),
      ProfileScreen(user: widget.user),
    ];

    String appBarTitle;
    IconData actionIcon;
    switch (_currentIndex) {
      case 1:
        appBarTitle = 'Users';
        actionIcon = Icons.help_outline_rounded;
        break;
      case 2:
        appBarTitle = 'Houses';
        actionIcon = Icons.help_outline_rounded;
        break;
      case 3:
        appBarTitle = 'Profile';
        actionIcon = Icons.settings_outlined;
        break;
      default:
        appBarTitle = 'KosMate Admin';
        actionIcon = Icons.help_outline_rounded;
    }

    return Scaffold(
      appBar: KosMateAppBar(title: appBarTitle, actionIcon: actionIcon),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFEBF3FA),
          elevation: 0,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppTheme.primaryColor),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group, color: AppTheme.primaryColor),
              label: 'Users',
            ),
            NavigationDestination(
              icon: Icon(Icons.apartment_outlined),
              selectedIcon: Icon(Icons.apartment, color: AppTheme.primaryColor),
              label: 'Houses',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.primaryColor),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 0: ADMIN HOME DASHBOARD (Matches Figma Admin_Main.png)
// -----------------------------------------------------------------------------
class _AdminHomeDashboard extends StatefulWidget {
  final UserModel user;
  final Function(int) onNavigateToTab;

  const _AdminHomeDashboard({
    required this.user,
    required this.onNavigateToTab,
  });

  @override
  State<_AdminHomeDashboard> createState() => _AdminHomeDashboardState();
}

class _AdminHomeDashboardState extends State<_AdminHomeDashboard> {
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
      final housesRes = await HouseService().getAllHouses();

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

  Future<void> _openAddUserDialog() async {
    final created = await UserFormDialog.show(context);
    if (created == true && mounted) {
      _loadAdminData();
    }
  }

  Future<void> _openAddHouseScreen() async {
    final created = await Navigator.push<HouseModel>(
      context,
      MaterialPageRoute(
        builder: (_) => HouseFormScreen(ownerId: widget.user.userId),
      ),
    );
    if (created != null && mounted) {
      _loadAdminData();
    }
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
            // Greeting Header
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
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),

            // 2 Stat Cards (Users & Houses)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF3FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD0E1F3)),
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
                                color: Color(0xFF475569),
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
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9E7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF9E8B5)),
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
                                color: Color(0xFF475569),
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
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions Heading
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

            // 3 Quick Action Tiles
            Row(
              children: [
                _buildQuickActionTile(
                  icon: Icons.person_add_outlined,
                  label: 'Add user',
                  onTap: _openAddUserDialog,
                ),
                const SizedBox(width: 12),
                _buildQuickActionTile(
                  icon: Icons.apartment_outlined,
                  label: 'Add house',
                  onTap: _openAddHouseScreen,
                ),
                const SizedBox(width: 12),
                _buildQuickActionTile(
                  icon: Icons.verified_user_outlined,
                  label: 'Manage roles',
                  onTap: () => widget.onNavigateToTab(1),
                ),
              ],
            ),
            const SizedBox(height: 26),

            // Recent Activity Heading with "View all"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent activity',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.foregroundColor,
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.onNavigateToTab(1),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recent Activity List Cards
            if (_recentUsers.isNotEmpty) ...[
              _buildActivityCard(
                icon: Icons.person_outline,
                title: 'User registered',
                subtitle:
                    '${_recentUsers.first.name} • ${_recentUsers.first.role.name.toUpperCase()}',
                trailingText: Formatters.formatDate(
                  _recentUsers.first.createdAt,
                ),
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
              ),
            ] else if (_recentUsers.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No recent activities yet.',
                    style: TextStyle(color: Color(0xFF64748B)),
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
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
    );
  }

  Widget _buildActivityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailingText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
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
                    color: Color(0xFF64748B),
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
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
