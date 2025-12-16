class SubmissionWithGradeModel {
  const SubmissionWithGradeModel({
    required this.id,
    required this.assignmentId,
    required this.userId,
    this.fileKey,
    this.studentName,
    this.email,
    this.fileSize,
    required this.submittedAt,
    this.grade,
    this.feedback,
    this.gradeStatus,
    this.gradeUpdatedAt,
  });

  final String id;
  final String assignmentId;
  final String userId;
  final String? fileKey;
  final String? studentName;
  final String? email;
  final int? fileSize;
  final DateTime submittedAt;
  final double? grade;
  final String? feedback;
  final String? gradeStatus;
  final DateTime? gradeUpdatedAt;

  factory SubmissionWithGradeModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return SubmissionWithGradeModel(
      id: json['id']?.toString() ?? '',
      assignmentId: json['assignmentId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      fileKey: json['fileKey'] as String?,
      studentName: json['studentName'] as String?,
      email: json['email'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
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
