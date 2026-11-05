import 'user_model.dart';

class HouseModel {
  final int houseId;
  final int ownerId;
  final String houseName;
  final String houseAddress;
  final String? description;
  final String? thumbnailUrl;
  final DateTime? createdAt;
  final UserModel? owner;

  HouseModel({
    required this.houseId,
    required this.ownerId,
    required this.houseName,
    required this.houseAddress,
    this.description,
    this.thumbnailUrl,
    this.createdAt,
    this.owner,
  });

  factory HouseModel.fromJson(Map<String, dynamic> json) {
    return HouseModel(
      houseId: json['house_id'] is int
          ? json['house_id'] as int
          : int.parse(json['house_id'].toString()),
      ownerId: json['owner_id'] is int
          ? json['owner_id'] as int
          : int.parse(json['owner_id'].toString()),
      houseName: json['house_name'] as String? ?? '',
      houseAddress: json['house_address'] as String? ?? '',
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      owner: json['users'] != null && json['users'] is Map<String, dynamic>
          ? UserModel.fromJson(json['users'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'owner_id': ownerId,
      'house_name': houseName,
      'house_address': houseAddress,
      'description': description,
      'thumbnail_url': thumbnailUrl,
    };
    if (includeId) {
      map['house_id'] = houseId;
    }
    return map;
  }

  HouseModel copyWith({
    int? houseId,
    int? ownerId,
    String? houseName,
    String? houseAddress,
    String? description,
    String? thumbnailUrl,
    DateTime? createdAt,
    UserModel? owner,
  }) {
    return HouseModel(
      houseId: houseId ?? this.houseId,
      ownerId: ownerId ?? this.ownerId,
      houseName: houseName ?? this.houseName,
      houseAddress: houseAddress ?? this.houseAddress,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      owner: owner ?? this.owner,
    );
  }
}

