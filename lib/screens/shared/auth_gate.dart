import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../admin/admin_main_screen.dart';
import '../auth/login_screen.dart';
import '../owner/owner_main_screen.dart';
import '../tenant/tenant_main_screen.dart';
import 'splash_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = sl.auth;
  StreamSubscription<AuthState>? _authSubscription;

  UserModel? _cachedUser;
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initAuthListener();
  }

  void _initAuthListener() {
    // Initial check
    final session = supabase.auth.currentSession;
    if (session == null) {
      _cachedUser = null;
      _currentUserId = null;
      _isLoading = false;
    } else {
      _currentUserId = session.user.id;
      _loadUserProfile();
    }

    // Subscribe to auth state changes
    _authSubscription = _authService.authStateChanges.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedOut || session == null) {
        if (mounted) {
          setState(() {
            _cachedUser = null;
            _currentUserId = null;
            _isLoading = false;
          });
        }
      } else if (session.user.id != _currentUserId) {
        // User changed
        _currentUserId = session.user.id;
        _cachedUser = null;
        _loadUserProfile();
      }
      // For tokenRefreshed or other events where the user ID has not changed,
      // keep _cachedUser intact to prevent rebuild flicker
    });
  }

  Future<void> _loadUserProfile() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final user = await _authService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _cachedUser = user;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;

    if (session == null) {
      return const LoginScreen();
    }

    if (_isLoading) {
      return const SplashScreen();
    }

    final user = _cachedUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_off_outlined,
                  size: 64,
                  color: AppTheme.warningColor,
                ),
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
                  onPressed: _loadUserProfile,
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
  }
}
