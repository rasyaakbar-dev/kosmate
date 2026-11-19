import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
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
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim(), 'phone': phone.trim(), 'role': role.name},
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
        } catch (_) {
          // Ignored if handled by DB trigger
        }
      }

      return response;
    } on AuthException catch (e) {
      throw AuthAppException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthAppException('Sign up failed. Please try again.', cause: e);
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthAppException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthAppException('Sign in failed. Please try again.', cause: e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthAppException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthAppException('Sign out failed.', cause: e);
    }
  }

  /// Get the current logged-in user's profile from public.users
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final response = await _client
          .from(SupabaseConstants.usersTable)
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } on AuthException catch (e) {
      throw AuthAppException(e.message, code: e.statusCode);
    } catch (e) {
      throw ServiceException('Failed to load user profile.', cause: e);
    }
  }

  /// Update the current user's profile
  Future<UserModel> updateProfile({
    required int userId,
    required String name,
    required String phone,
    String? avatarUrl,
  }) async {
    try {
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
    } catch (e) {
      throw ServiceException('Failed to update profile.', cause: e);
    }
  }
}
