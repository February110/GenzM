import '../../core/models/notification_dto.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.classroomId,
    this.assignmentId,
    this.actorName,
    this.actorAvatar,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final String? classroomId;
  final String? assignmentId;
  final String? actorName;
  final String? actorAvatar;
  final bool isRead;
  final DateTime createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? '',
      classroomId: json['classroomId']?.toString(),
      assignmentId: json['assignmentId']?.toString(),
      actorName: json['actorName'] as String?,
      actorAvatar: json['actorAvatar'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: parseDate(json['createdAt']),
    );
  }

  factory NotificationModel.fromDto(NotificationDto dto) {
    return NotificationModel(
      id: dto.id,
      title: dto.title,
      message: dto.message,
      type: dto.type,
      classroomId: dto.classroomId,
      assignmentId: dto.assignmentId,
      actorName: dto.actorName,
      actorAvatar: dto.actorAvatar,
      isRead: dto.isRead,
      createdAt: dto.createdAt,
    );
  }

  NotificationModel copyWith({
    bool? isRead,
  }) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      type: type,
      classroomId: classroomId,
      assignmentId: assignmentId,
      actorName: actorName,
      actorAvatar: actorAvatar,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
