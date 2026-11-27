import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/json_helpers.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class UserService {
  final SupabaseClient _client;
  final AuthService _authService;

  UserService([AuthService? authService, SupabaseClient? client])
    : _client = client ?? Supabase.instance.client,
      _authService = authService ?? AuthService(client);

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
        final sanitized = searchQuery
            .trim()
            .replaceAll(RegExp(r'[,()*%\\]'), '')
            .trim();
        if (sanitized.isNotEmpty) {
          query = query.or(
            'name.ilike.%$sanitized%,email.ilike.%$sanitized%,phone.ilike.%$sanitized%',
          );
        }
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).mapToModel(UserModel.fromJson);
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to load users.', code: e.code, cause: e);
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
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to load user.', code: e.code, cause: e);
    } catch (e) {
      throw ServiceException('Failed to load user.', cause: e);
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final response = await _client
          .from(SupabaseConstants.usersTable)
          .select()
          .eq('email', email.trim())
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to load user.', code: e.code, cause: e);
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
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to update user.', code: e.code, cause: e);
    } catch (e) {
      throw ServiceException('Failed to update user.', cause: e);
    }
  }

  Future<UserModel> updateAvatarUrl({
    required int userId,
    required String avatarUrl,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.usersTable)
          .update({'avatar_url': avatarUrl})
          .eq('user_id', userId)
          .select()
          .single();

      return UserModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to update user avatar.',
        code: e.code,
        cause: e,
      );
    } catch (e) {
      throw ServiceException('Failed to update user avatar.', cause: e);
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
    } on PostgrestException catch (e) {
      throw ServiceException(
        'Failed to update user role.',
        code: e.code,
        cause: e,
      );
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
    } on PostgrestException catch (e) {
      throw ServiceException('Failed to delete user.', code: e.code, cause: e);
    } catch (e) {
      throw ServiceException('Failed to delete user.', cause: e);
    }
  }
}
