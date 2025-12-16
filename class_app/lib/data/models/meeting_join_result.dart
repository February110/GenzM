import 'meeting_model.dart';

class MeetingJoinResult {
  const MeetingJoinResult({
    required this.meeting,
    required this.classroom,
    required this.role,
  });

  final MeetingModel meeting;
  final MeetingClassroom classroom;
  final String role;
}

class MeetingClassroom {
  const MeetingClassroom({
    required this.id,
    required this.name,
    this.members = const [],
  });

  final String id;
  final String name;
  final List<MeetingMember> members;
}

class MeetingMember {
  const MeetingMember({
    required this.userId,
    required this.fullName,
    this.avatar,
  });

  final String userId;
  final String fullName;
  final String? avatar;
}
