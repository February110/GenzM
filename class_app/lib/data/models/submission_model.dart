class SubmissionModel {
  const SubmissionModel({
    required this.id,
    required this.assignmentId,
    required this.fileKey,
    required this.fileSize,
    required this.submittedAt,
    this.grade,
    this.feedback,
    this.gradeStatus,
    this.gradeUpdatedAt,
  });

  final String id;
  final String assignmentId;
  final String fileKey;
  final int fileSize;
  final DateTime submittedAt;
  final double? grade;
  final String? feedback;
  final String? gradeStatus;
  final DateTime? gradeUpdatedAt;

  factory SubmissionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return SubmissionModel(
      id: json['id']?.toString() ?? '',
      assignmentId: json['assignmentId']?.toString() ?? '',
      fileKey: json['fileKey'] as String? ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      submittedAt: parseDate(json['submittedAt']),
      grade: (json['grade'] as num?)?.toDouble(),
      feedback: json['feedback'] as String?,
      gradeStatus: json['gradeStatus'] as String?,
      gradeUpdatedAt: json['gradeUpdatedAt'] != null
          ? DateTime.tryParse(json['gradeUpdatedAt'].toString())
          : null,
    );
  }
}
