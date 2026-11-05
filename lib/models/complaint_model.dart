import 'user_model.dart';
import 'room_model.dart';

enum ComplaintCategory {
  maintenance,
  cleanliness,
  noise,
  security,
  other;

  static ComplaintCategory fromString(String value) {
    return ComplaintCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ComplaintCategory.other,
    );
  }

  String get displayName {
    switch (this) {
      case ComplaintCategory.maintenance:
        return 'Maintenance';
      case ComplaintCategory.cleanliness:
        return 'Cleanliness';
      case ComplaintCategory.noise:
        return 'Noise';
      case ComplaintCategory.security:
        return 'Security';
      case ComplaintCategory.other:
        return 'Other';
    }
  }
}

enum ComplaintPriority {
  low,
  medium,
  high,
  urgent;

  static ComplaintPriority fromString(String value) {
    return ComplaintPriority.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ComplaintPriority.medium,
    );
  }

  String get displayName {
    switch (this) {
      case ComplaintPriority.low:
        return 'Low';
      case ComplaintPriority.medium:
        return 'Medium';
      case ComplaintPriority.high:
        return 'High';
      case ComplaintPriority.urgent:
        return 'Urgent';
    }
  }
}

enum ComplaintStatus {
  pending,
  inProgress,
  resolved,
  rejected;

  static ComplaintStatus fromString(String value) {
    if (value.toLowerCase() == 'in_progress') return ComplaintStatus.inProgress;
    return ComplaintStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ComplaintStatus.pending,
    );
  }

  String get dbValue {
    switch (this) {
      case ComplaintStatus.inProgress:
        return 'in_progress';
      default:
        return name;
    }
  }

  String get displayName {
    switch (this) {
      case ComplaintStatus.pending:
        return 'Pending';
      case ComplaintStatus.inProgress:
        return 'In Progress';
      case ComplaintStatus.resolved:
        return 'Resolved';
      case ComplaintStatus.rejected:
        return 'Rejected';
    }
  }
}

class ComplaintModel {
  final int complaintId;
  final int userId;
  final int roomId;
  final ComplaintCategory category;
  final String title;
  final String description;
  final ComplaintPriority priority;
  final DateTime date;
  final String? response;
  final String? attachmentUrl;
  final ComplaintStatus status;
  final DateTime? createdAt;
  final UserModel? user;
  final RoomModel? room;

  ComplaintModel({
    required this.complaintId,
    required this.userId,
    required this.roomId,
    required this.category,
    required this.title,
    required this.description,
    required this.priority,
    required this.date,
    this.response,
    this.attachmentUrl,
    required this.status,
    this.createdAt,
    this.user,
    this.room,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      complaintId: json['complaint_id'] is int
          ? json['complaint_id'] as int
          : int.parse(json['complaint_id'].toString()),
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.parse(json['user_id'].toString()),
      roomId: json['room_id'] is int
          ? json['room_id'] as int
          : int.parse(json['room_id'].toString()),
      category: ComplaintCategory.fromString(
        json['category'] as String? ?? 'other',
      ),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priority: ComplaintPriority.fromString(
        json['priority'] as String? ?? 'medium',
      ),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      response: json['response'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      status: ComplaintStatus.fromString(
        json['status'] as String? ?? 'pending',
      ),
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
      'category': category.name,
      'title': title,
      'description': description,
      'priority': priority.name,
      'date': date.toIso8601String().split('T').first,
      'response': response,
      'attachment_url': attachmentUrl,
      'status': status.dbValue,
    };
    if (includeId) {
      map['complaint_id'] = complaintId;
    }
    return map;
  }

  ComplaintModel copyWith({
    int? complaintId,
    int? userId,
    int? roomId,
    ComplaintCategory? category,
    String? title,
    String? description,
    ComplaintPriority? priority,
    DateTime? date,
    String? response,
    String? attachmentUrl,
    ComplaintStatus? status,
    DateTime? createdAt,
    UserModel? user,
    RoomModel? room,
  }) {
    return ComplaintModel(
      complaintId: complaintId ?? this.complaintId,
      userId: userId ?? this.userId,
      roomId: roomId ?? this.roomId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      date: date ?? this.date,
      response: response ?? this.response,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      user: user ?? this.user,
      room: room ?? this.room,
    );
  }
}
