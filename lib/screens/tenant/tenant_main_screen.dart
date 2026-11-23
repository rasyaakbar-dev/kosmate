import 'package:flutter/material.dart';

import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/kosmate_app_bar.dart';
import '../../models/user_model.dart';
import '../shared/profile_screen.dart';
import 'home/tenant_home_tab.dart';
import 'payments/tenant_payments_tab.dart';
import 'rooms/tenant_rooms_tab.dart';

class TenantMainScreen extends StatefulWidget {
  final UserModel user;

  const TenantMainScreen({super.key, required this.user});

  @override
  State<TenantMainScreen> createState() => _TenantMainScreenState();
}

class _TenantMainScreenState extends State<TenantMainScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      TenantHomeTab(user: widget.user, onNavigateToTab: _navigateToTab),
      TenantRoomsTab(user: widget.user),
      TenantPaymentsTab(user: widget.user),
      ProfileScreen(user: widget.user),
    ];

    String appBarTitle;
    switch (_currentIndex) {
      case 1:
        appBarTitle = 'Rooms';
        break;
      case 2:
        appBarTitle = 'Payments';
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
            label: 'Room',
          ),
          AppNavigationItem(
            icon: Icons.mail_outline_rounded,
            activeIcon: Icons.mail,
            label: 'Payment',
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
