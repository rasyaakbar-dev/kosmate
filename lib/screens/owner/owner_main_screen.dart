import 'package:flutter/material.dart';

import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../models/user_model.dart';
import '../shared/profile_screen.dart';
import 'home/owner_home_tab.dart';
import 'management/owner_management_hub_tab.dart';
import 'rooms/owner_rooms_tab.dart';

class OwnerMainScreen extends StatefulWidget {
  final UserModel user;

  const OwnerMainScreen({super.key, required this.user});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      OwnerHomeTab(user: widget.user, onNavigateToTab: _navigateToTab),
      OwnerRoomsTab(currentUser: widget.user),
      OwnerManagementHubTab(user: widget.user),
      ProfileScreen(user: widget.user),
    ];

    String appBarTitle;
    switch (_currentIndex) {
      case 1:
        appBarTitle = 'Rooms';
        break;
      case 2:
        appBarTitle = 'Management';
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
            icon: Icons.sensor_door_outlined,
            activeIcon: Icons.sensor_door,
            label: 'Rooms',
          ),
          AppNavigationItem(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment,
            label: 'Management',
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
