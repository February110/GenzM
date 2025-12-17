class NotificationDto {
  const NotificationDto({
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

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return NotificationDto(
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
}
