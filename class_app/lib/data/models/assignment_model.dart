class AssignmentModel {
  const AssignmentModel({
    required this.id,
    required this.title,
    this.dueAt,
    this.maxPoints,
    this.classroomId,
    this.instructions,
    this.createdAt,
  });

  final String id;
  final String title;
  final DateTime? dueAt;
  final int? maxPoints;
  final String? classroomId;
  final String? instructions;
  final DateTime? createdAt;

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return AssignmentModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      dueAt: parseDate(json['dueAt']),
      maxPoints: json['maxPoints'] as int?,
      classroomId: json['classroomId']?.toString(),
      instructions: json['instructions'] as String?,
      createdAt: parseDate(json['createdAt']),
    );
  }
}
