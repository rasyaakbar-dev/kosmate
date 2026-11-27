import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/user_model.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  bool get hasActiveSession => _client.auth.currentSession != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

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

      // Ensure profile row exists if DB trigger did not create it.
      final authUser = response.user;
      if (authUser != null) {
        try {
          final existing = await _client
              .from(SupabaseConstants.usersTable)
              .select('user_id')
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
        } catch (_) {}
      }

      return response;
    } on AuthException catch (e) {
      throw AuthAppException(e.message, code: e.statusCode, cause: e);
    } catch (e) {
      throw AuthAppException('Sign up failed. Please try again.', cause: e);
    }
  }

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
      throw AuthAppException(e.message, code: e.statusCode, cause: e);
    } catch (e) {
      throw AuthAppException('Sign in failed. Please try again.', cause: e);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthAppException(e.message, code: e.statusCode, cause: e);
    } catch (e) {
      throw AuthAppException('Sign out failed.', cause: e);
    }
  }

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
      throw AuthAppException(e.message, code: e.statusCode, cause: e);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to load user profile.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to load user profile.', cause: e);
    }
  }

  Future<UserModel> updateProfile({
    required int userId,
    required String name,
    required String phone,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'name': name.trim(),
        'phone': phone.trim(),
      };
      if (clearAvatar) {
        updateData['avatar_url'] = null;
      } else if (avatarUrl != null) {
        updateData['avatar_url'] = avatarUrl;
      }

      final response = await _client
          .from(SupabaseConstants.usersTable)
          .update(updateData)
          .eq('user_id', userId)
          .select()
          .single();

      return UserModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to update profile.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to update profile.', cause: e);
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw AuthAppException(e.message, code: e.statusCode, cause: e);
    } catch (e) {
      throw AuthAppException('Failed to send password reset email.', cause: e);
    }
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw AuthAppException(e.message, code: e.statusCode, cause: e);
    } catch (e) {
      throw AuthAppException('Failed to update password.', cause: e);
    }
  }

  Future<void> deleteAccount(int userId) async {
    try {
      await _client
          .from(SupabaseConstants.usersTable)
          .delete()
          .eq('user_id', userId);

      await signOut();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to delete account.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to delete account.', cause: e);
    }
  }
}
