import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/supabase_constants.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../tenant/tenant_main_screen.dart';
import '../owner/owner_main_screen.dart';
import '../admin/admin_main_screen.dart';
import 'splash_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (session == null) {
          return const LoginScreen();
        }

        // Authenticated, load user profile from public.users
        return FutureBuilder<UserModel?>(
          future: _authService.getCurrentUserProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            final user = profileSnapshot.data;
            if (user == null) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_off_outlined, size: 64, color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text(
                          'Profile not found or initializing.',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'If you just registered, your profile is being generated.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => _authService.signOut(),
                          child: const Text('Back to Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Route to appropriate screen based on role
            switch (user.role) {
              case UserRole.admin:
                return AdminMainScreen(user: user);
              case UserRole.owner:
                return OwnerMainScreen(user: user);
              case UserRole.tenant:
                return TenantMainScreen(user: user);
            }
          },
        );
      },
    );
  }
}
