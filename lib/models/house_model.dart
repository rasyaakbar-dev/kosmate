import 'package:flutter/foundation.dart';

import '../core/utils/json_helpers.dart';
import 'user_model.dart';

@immutable
class HouseModel {
  final int houseId;
  final int ownerId;
  final String houseName;
  final String houseAddress;
  final String? description;
  final String? thumbnailUrl;
  final DateTime? createdAt;
  final UserModel? owner;

  const HouseModel({
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
      houseId: parseIntField(json['house_id']),
      ownerId: parseIntField(json['owner_id']),
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HouseModel &&
        other.houseId == houseId &&
        other.ownerId == ownerId &&
        other.houseName == houseName &&
        other.houseAddress == houseAddress &&
        other.description == description &&
        other.thumbnailUrl == thumbnailUrl &&
        other.createdAt == createdAt &&
        other.owner == owner;
  }

  @override
  int get hashCode => Object.hash(
    houseId,
    ownerId,
    houseName,
    houseAddress,
    description,
    thumbnailUrl,
    createdAt,
    owner,
  );
}
