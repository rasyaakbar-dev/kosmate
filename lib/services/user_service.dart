import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/supabase_helpers.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class UserService {
  final SupabaseClient _client = supabase;
  final AuthService _authService;

  UserService([AuthService? authService])
    : _authService = authService ?? AuthService();

  Future<List<UserModel>> getAllUsers({
    UserRole? roleFilter,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from(SupabaseConstants.usersTable).select();

      if (roleFilter != null) {
        query = query.eq('role', roleFilter.name);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = searchQuery.trim();
        query = query.or(
          'name.ilike.%$term%,email.ilike.%$term%,phone.ilike.%$term%',
        );
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).mapToModel(UserModel.fromJson);
    } catch (e) {
      throw ServiceException('Failed to load users.', cause: e);
    }
  }

  Future<UserModel?> getUserById(int userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.usersTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to load user.', cause: e);
    }
  }

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  }) async {
    try {
      await _authService.signUp(
        email: email.trim(),
        password: password,
        name: name.trim(),
        phone: phone.trim(),
        role: role,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServiceException('Failed to create user.', cause: e);
    }
  }

  Future<UserModel> updateUser({
    required int userId,
    required String name,
    required String phone,
    required UserRole role,
    String? avatarUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'name': name.trim(),
        'phone': phone.trim(),
        'role': role.name,
      };
      if (avatarUrl != null) {
        updateData['avatar_url'] = avatarUrl.trim();
      }

      final response = await _client
          .from(SupabaseConstants.usersTable)
          .update(updateData)
          .eq('user_id', userId)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to update user.', cause: e);
    }
  }

  Future<UserModel> updateUserRole({
    required int userId,
    required UserRole newRole,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.usersTable)
          .update({'role': newRole.name})
          .eq('user_id', userId)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      throw ServiceException('Failed to update user role.', cause: e);
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await _client
          .from(SupabaseConstants.usersTable)
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      throw ServiceException('Failed to delete user.', cause: e);
    }
  }
}
