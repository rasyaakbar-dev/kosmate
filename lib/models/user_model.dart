enum UserRole {
  admin,
  owner,
  tenant;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.tenant,
    );
  }
}

class UserModel {
  final int userId;
  final String? authId;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final DateTime? createdAt;

  UserModel({
    required this.userId,
    this.authId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.parse(json['user_id'].toString()),
      authId: json['auth_id'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'tenant'),
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'avatar_url': avatarUrl,
    };
    if (includeId) {
      map['user_id'] = userId;
      map['auth_id'] = authId;
    }
    return map;
  }

  UserModel copyWith({
    int? userId,
    String? authId,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      authId: authId ?? this.authId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
