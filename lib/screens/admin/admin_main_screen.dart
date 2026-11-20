import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../models/user_model.dart';
import '../shared/profile_screen.dart';
import 'dashboard/admin_dashboard_tab.dart';
import 'houses/admin_houses_tab.dart';
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
      AdminDashboardTab(user: widget.user, onNavigateToTab: _navigateToTab),
      UserManagementTab(currentUser: widget.user),
      AdminHousesTab(currentUser: widget.user),
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
        appBarTitle = 'Boarding houses';
        actionIcon = Icons.help_outline_rounded;
        break;
      case 3:
        appBarTitle = 'Profile';
        actionIcon = Icons.settings_outlined;
        break;
      default:
        appBarTitle = 'KosMate';
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
