import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class UserService {
  final SupabaseClient _client = supabase;
  final AuthService _authService = AuthService();

  /// Fetch all users with optional role and search query filtering
  Future<List<UserModel>> getAllUsers({
    UserRole? roleFilter,
    String? searchQuery,
  }) async {
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

    return (response as List)
        .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Fetch single user by user ID
  Future<UserModel?> getUserById(int userId) async {
    final response = await _client
        .from(SupabaseConstants.usersTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserModel.fromJson(response);
  }

  /// Create a new user (via Supabase Auth sign up)
  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  }) async {
    await _authService.signUp(
      email: email.trim(),
      password: password,
      name: name.trim(),
      phone: phone.trim(),
      role: role,
    );
  }

  /// Update an existing user's profile details
  Future<UserModel> updateUser({
    required int userId,
    required String name,
    required String phone,
    required UserRole role,
    String? avatarUrl,
  }) async {
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
  }

  /// Quick update for user role
  Future<UserModel> updateUserRole({
    required int userId,
    required UserRole newRole,
  }) async {
    final response = await _client
        .from(SupabaseConstants.usersTable)
        .update({'role': newRole.name})
        .eq('user_id', userId)
        .select()
        .single();

    return UserModel.fromJson(response);
  }

  /// Delete a user by ID
  Future<void> deleteUser(int userId) async {
    await _client
        .from(SupabaseConstants.usersTable)
        .delete()
        .eq('user_id', userId);
  }
}
