import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
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
    IconData actionIcon;
    switch (_currentIndex) {
      case 1:
        appBarTitle = 'Rooms';
        actionIcon = Icons.help_outline_rounded;
        break;
      case 2:
        appBarTitle = 'Payments';
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
              icon: Icon(Icons.sensor_door_outlined),
              selectedIcon: Icon(
                Icons.sensor_door,
                color: AppTheme.primaryColor,
              ),
              label: 'Room',
            ),
            NavigationDestination(
              icon: Icon(Icons.mail_outline_rounded),
              selectedIcon: Icon(Icons.mail, color: AppTheme.primaryColor),
              label: 'Payment',
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
