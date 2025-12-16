class MeetingModel {
  const MeetingModel({
    required this.id,
    required this.roomCode,
    required this.title,
    required this.status,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String roomCode;
  final String title;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v);
      }
      return null;
    }

    String pickString(String lower, String pascal) {
      return (json[lower] ?? json[pascal])?.toString() ?? '';
    }

    return MeetingModel(
      id: pickString('id', 'Id'),
      roomCode: pickString('roomCode', 'RoomCode'),
      title: pickString('title', 'Title'),
      status: pickString('status', 'Status'),
      startedAt: parseDate(json['startedAt'] ?? json['StartedAt']),
      endedAt: parseDate(json['endedAt'] ?? json['EndedAt']),
    );
  }
}
