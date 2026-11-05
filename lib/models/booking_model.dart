import 'user_model.dart';
import 'room_model.dart';

enum BookingStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static BookingStatus fromString(String value) {
    return BookingStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => BookingStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.approved:
        return 'Approved';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class BookingModel {
  final int bookingId;
  final int userId;
  final int roomId;
  final DateTime requestDate;
  final BookingStatus status;
  final String? notes;
  final DateTime? createdAt;
  final UserModel? user;
  final RoomModel? room;

  BookingModel({
    required this.bookingId,
    required this.userId,
    required this.roomId,
    required this.requestDate,
    required this.status,
    this.notes,
    this.createdAt,
    this.user,
    this.room,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      bookingId: json['booking_id'] is int
          ? json['booking_id'] as int
          : int.parse(json['booking_id'].toString()),
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.parse(json['user_id'].toString()),
      roomId: json['room_id'] is int
          ? json['room_id'] as int
          : int.parse(json['room_id'].toString()),
      requestDate: json['request_date'] != null
          ? DateTime.tryParse(json['request_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: BookingStatus.fromString(json['status'] as String? ?? 'pending'),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      user: json['users'] != null && json['users'] is Map<String, dynamic>
          ? UserModel.fromJson(json['users'] as Map<String, dynamic>)
          : null,
      room: json['room'] != null && json['room'] is Map<String, dynamic>
          ? RoomModel.fromJson(json['room'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'user_id': userId,
      'room_id': roomId,
      'request_date': requestDate.toIso8601String().split('T').first,
      'status': status.name,
      'notes': notes,
    };
    if (includeId) {
      map['booking_id'] = bookingId;
    }
    return map;
  }

  BookingModel copyWith({
    int? bookingId,
    int? userId,
    int? roomId,
    DateTime? requestDate,
    BookingStatus? status,
    String? notes,
    DateTime? createdAt,
    UserModel? user,
    RoomModel? room,
  }) {
    return BookingModel(
      bookingId: bookingId ?? this.bookingId,
      userId: userId ?? this.userId,
      roomId: roomId ?? this.roomId,
      requestDate: requestDate ?? this.requestDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      user: user ?? this.user,
      room: room ?? this.room,
    );
  }
}

