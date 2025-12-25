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
      if (v is DateTime) {
        return v;
      }
      return DateTime.now();
    }

    // Hỗ trợ cả camelCase và PascalCase từ C# backend
    final id = json['id'] ?? json['Id'];
    final announcementId = json['announcementId'] ?? json['AnnouncementId'];
    final userId = json['userId'] ?? json['UserId'];
    final content = json['content'] ?? json['Content'];
    final userName = json['userName'] ?? json['UserName'];
    final userAvatar = json['userAvatar'] ?? json['UserAvatar'];
    final createdAt = json['createdAt'] ?? json['CreatedAt'];

    return AnnouncementCommentModel(
      id: id?.toString() ?? '',
      announcementId: announcementId?.toString() ?? '',
      userId: userId?.toString() ?? '',
      content: content as String? ?? '',
      userName: userName as String?,
      userAvatar: userAvatar as String?,
      createdAt: parseDate(createdAt),
    );
  }
}
