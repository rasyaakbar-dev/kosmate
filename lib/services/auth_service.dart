import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../models/user_model.dart';

class AuthService {
  final SupabaseClient _client = supabase;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up a new user and store profile metadata
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'name': name.trim(),
        'phone': phone.trim(),
        'role': role.name,
      },
    );

    // Fallback: If trigger didn't insert the profile, ensure it exists
    final authUser = response.user;
    if (authUser != null) {
      try {
        final existing = await _client
            .from(SupabaseConstants.usersTable)
            .select()
            .eq('auth_id', authUser.id)
            .maybeSingle();

        if (existing == null) {
          await _client.from(SupabaseConstants.usersTable).insert({
            'auth_id': authUser.id,
            'name': name.trim(),
            'email': email.trim(),
            'phone': phone.trim(),
            'role': role.name,
          });
        }
      } catch (e) {
        // Ignored if handled by DB trigger
      }
    }

    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get the current logged-in user's profile from public.users
  Future<UserModel?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response = await _client
        .from(SupabaseConstants.usersTable)
        .select()
        .eq('auth_id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return UserModel.fromJson(response);
  }

  /// Update the current user's profile
  Future<UserModel> updateProfile({
    required int userId,
    required String name,
    required String phone,
    String? avatarUrl,
  }) async {
    final updateData = <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
    };
    if (avatarUrl != null) {
      updateData['avatar_url'] = avatarUrl;
    }

    final response = await _client
        .from(SupabaseConstants.usersTable)
        .update(updateData)
        .eq('user_id', userId)
        .select()
        .single();

    return UserModel.fromJson(response);
  }
}
