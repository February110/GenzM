class ClassroomModel {
  const ClassroomModel({
    required this.id,
    required this.name,
    this.description,
    this.inviteCode,
    this.section,
    this.bannerUrl,
    this.role,
    this.inviteCodeVisible,
  });

  final String id;
  final String name;
  final String? description;
  final String? inviteCode;
  final String? section;
  final String? bannerUrl;
  final String? role;
  final bool? inviteCodeVisible;

  factory ClassroomModel.fromJson(Map<String, dynamic> json) {
    return ClassroomModel(
      id: json['classroomId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      inviteCode: json['inviteCode'] as String?,
      section: json['section'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      role: json['role'] as String?,
      inviteCodeVisible: json['inviteCodeVisible'] as bool?,
    );
  }
}
