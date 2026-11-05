import 'package:flutter/material.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kosmate_logo.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../admin/admin_main_screen.dart';
import '../auth/login_screen.dart';
import '../owner/owner_main_screen.dart';
import '../tenant/tenant_main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Hold splash screen for 3 seconds as requested
    final timerFuture = Future.delayed(const Duration(seconds: 3));

    // Check session & preload profile in parallel
    UserModel? user;
    try {
      final session = supabase.auth.currentSession;
      if (session != null) {
        user = await _authService.getCurrentUserProfile();
      }
    } catch (_) {
      // Ignored; falls back to login screen
    }

    // Wait until 3 seconds have fully elapsed
    await timerFuture;
    if (!mounted) return;

    Widget destination;
    if (user == null) {
      destination = const LoginScreen();
    } else {
      switch (user.role) {
        case UserRole.admin:
          destination = AdminMainScreen(user: user);
          break;
        case UserRole.owner:
          destination = OwnerMainScreen(user: user);
          break;
        case UserRole.tenant:
          destination = TenantMainScreen(user: user);
          break;
      }
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => destination,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            KosMateLogo(
              size: 110,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              'KosMate',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
