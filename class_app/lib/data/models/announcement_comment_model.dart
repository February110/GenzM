class AnnouncementCommentModel {
  const AnnouncementCommentModel({
    required this.id,
    required this.announcementId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.userName,
    this.userAvatar,
  });

  final String id;
  final String announcementId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatar;

  factory AnnouncementCommentModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return AnnouncementCommentModel(
      id: json['id']?.toString() ?? '',
      announcementId: json['announcementId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      content: json['content'] as String? ?? '',
      userName: json['userName'] as String?,
      userAvatar: json['userAvatar'] as String?,
      createdAt: parseDate(json['createdAt']),
    );
  }
}
