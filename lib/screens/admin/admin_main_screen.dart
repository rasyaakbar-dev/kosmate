import 'package:flutter/material.dart';

import '../../core/widgets/app_navigation_bar.dart';
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
    switch (_currentIndex) {
      case 1:
        appBarTitle = 'Users';
        break;
      case 2:
        appBarTitle = 'Boarding houses';
        break;
      case 3:
        appBarTitle = 'Profile';
        break;
      default:
        appBarTitle = 'KosMate';
    }

    return Scaffold(
      appBar: KosMateAppBar(title: appBarTitle),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: AppNavigationBar(
        currentIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          AppNavigationItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
          ),
          AppNavigationItem(
            icon: Icons.group_outlined,
            activeIcon: Icons.group,
            label: 'Users',
          ),
          AppNavigationItem(
            icon: Icons.apartment_outlined,
            activeIcon: Icons.apartment,
            label: 'Houses',
          ),
          AppNavigationItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
