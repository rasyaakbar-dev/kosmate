import 'house_model.dart';

enum RoomStatus {
  available,
  occupied,
  maintenance,
  unavailable;

  static RoomStatus fromString(String value) {
    return RoomStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RoomStatus.available,
    );
  }

  String get displayName {
    switch (this) {
      case RoomStatus.available:
        return 'Available';
      case RoomStatus.occupied:
        return 'Occupied';
      case RoomStatus.maintenance:
        return 'Maintenance';
      case RoomStatus.unavailable:
        return 'Unavailable';
    }
  }
}

class RoomModel {
  final int roomId;
  final int houseId;
  final String roomNumber;
  final String roomType;
  final double price;
  final String? facilities;
  final List<String> imageUrls;
  final RoomStatus status;
  final DateTime? createdAt;
  final HouseModel? house;

  RoomModel({
    required this.roomId,
    required this.houseId,
    required this.roomNumber,
    required this.roomType,
    required this.price,
    this.facilities,
    this.imageUrls = const [],
    required this.status,
    this.createdAt,
    this.house,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedImages = [];
    if (json['image_urls'] != null) {
      if (json['image_urls'] is List) {
        parsedImages = (json['image_urls'] as List)
            .map((e) => e.toString())
            .toList();
      }
    }

    return RoomModel(
      roomId: json['room_id'] is int
          ? json['room_id'] as int
          : int.parse(json['room_id'].toString()),
      houseId: json['house_id'] is int
          ? json['house_id'] as int
          : int.parse(json['house_id'].toString()),
      roomNumber: json['room_number'] as String? ?? '',
      roomType: json['room_type'] as String? ?? '',
      price: json['price'] != null
          ? double.tryParse(json['price'].toString()) ?? 0.0
          : 0.0,
      facilities: json['facilities'] as String?,
      imageUrls: parsedImages,
      status: RoomStatus.fromString(json['status'] as String? ?? 'available'),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      house: json['house'] != null && json['house'] is Map<String, dynamic>
          ? HouseModel.fromJson(json['house'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'house_id': houseId,
      'room_number': roomNumber,
      'room_type': roomType,
      'price': price,
      'facilities': facilities,
      'image_urls': imageUrls,
      'status': status.name,
    };
    if (includeId) {
      map['room_id'] = roomId;
    }
    return map;
  }

  RoomModel copyWith({
    int? roomId,
    int? houseId,
    String? roomNumber,
    String? roomType,
    double? price,
    String? facilities,
    List<String>? imageUrls,
    RoomStatus? status,
    DateTime? createdAt,
    HouseModel? house,
  }) {
    return RoomModel(
      roomId: roomId ?? this.roomId,
      houseId: houseId ?? this.houseId,
      roomNumber: roomNumber ?? this.roomNumber,
      roomType: roomType ?? this.roomType,
      price: price ?? this.price,
      facilities: facilities ?? this.facilities,
      imageUrls: imageUrls ?? this.imageUrls,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      house: house ?? this.house,
    );
  }
}

