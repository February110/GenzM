class AssignmentCommentModel {
  const AssignmentCommentModel({
    required this.id,
    required this.assignmentId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.userName,
    this.targetUserId,
  });

  final String id;
  final String assignmentId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? userName;
  final String? targetUserId;

  factory AssignmentCommentModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return AssignmentCommentModel(
      id: json['id']?.toString() ?? '',
      assignmentId: json['assignmentId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      content: json['content'] as String? ?? '',
      userName: json['userName'] as String?,
      targetUserId: json['targetUserId']?.toString(),
      createdAt: parseDate(json['createdAt']),
    );
  }
}
