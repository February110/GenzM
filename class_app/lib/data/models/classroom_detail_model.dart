import 'assignment_model.dart';

class ClassroomDetailModel {
  const ClassroomDetailModel({
    required this.id,
    required this.name,
    this.description,
    this.inviteCode,
    this.bannerUrl,
    this.section,
    this.room,
    this.schedule,
    this.inviteCodeVisible,
    this.members = const [],
    this.assignments = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String? inviteCode;
  final String? bannerUrl;
  final String? section;
  final String? room;
  final String? schedule;
  final bool? inviteCodeVisible;
  final List<ClassroomMember> members;
  final List<AssignmentModel> assignments;

  factory ClassroomDetailModel.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'] ?? json['Members'];
    final assignmentsJson = json['assignments'] ?? json['Assignments'];

    return ClassroomDetailModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      inviteCode: json['inviteCode'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      section: json['section'] as String?,
      room: json['room'] as String?,
      schedule: json['schedule'] as String?,
      inviteCodeVisible: json['inviteCodeVisible'] as bool?,
      members: membersJson is Iterable
          ? membersJson
                .whereType<Map<String, dynamic>>()
                .map(ClassroomMember.fromJson)
                .toList()
          : const [],
      assignments: assignmentsJson is Iterable
          ? assignmentsJson
                .whereType<Map<String, dynamic>>()
                .map(AssignmentModel.fromJson)
                .toList()
          : const [],
    );
  }
}

class ClassroomMember {
  const ClassroomMember({
    required this.userId,
    this.fullName,
    this.email,
    this.avatar,
    this.role,
  });

  final String userId;
  final String? fullName;
  final String? email;
  final String? avatar;
  final String? role;

  factory ClassroomMember.fromJson(Map<String, dynamic> json) {
    return ClassroomMember(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName'] as String?,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
      role: json['role'] as String?,
    );
  }
}
