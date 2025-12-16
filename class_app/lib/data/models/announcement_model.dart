import 'announcement_attachment_model.dart';

class AnnouncementModel {
  const AnnouncementModel({
    required this.id,
    required this.classroomId,
    required this.content,
    required this.createdAt,
    this.attachments = const [],
    this.isForAll,
    this.targetUserIds = const [],
    this.createdBy,
    this.createdByName,
    this.createdByAvatar,
  });

  final String id;
  final String classroomId;
  final String content;
  final DateTime createdAt;
  final List<AnnouncementAttachmentModel> attachments;
  final bool? isForAll;
  final List<String> targetUserIds;
  final String? createdBy;
  final String? createdByName;
  final String? createdByAvatar;

  AnnouncementModel copyWith({
    String? id,
    String? classroomId,
    String? content,
    DateTime? createdAt,
    bool? isForAll,
    List<String>? targetUserIds,
    String? createdBy,
    String? createdByName,
    String? createdByAvatar,
    List<AnnouncementAttachmentModel>? attachments,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      classroomId: classroomId ?? this.classroomId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      attachments: attachments ?? this.attachments,
      isForAll: isForAll ?? this.isForAll,
      targetUserIds: targetUserIds ?? this.targetUserIds,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdByAvatar: createdByAvatar ?? this.createdByAvatar,
    );
  }

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final targets = <String>[];
    final rawTargets = json['targetUserIds'];
    if (rawTargets is List) {
      targets.addAll(rawTargets.map((e) => e.toString()));
    } else if (rawTargets is String && rawTargets.isNotEmpty) {
      targets.addAll(
        rawTargets
            .replaceAll('[', '')
            .replaceAll(']', '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    final List<AnnouncementAttachmentModel> attachments = [];
    final rawAttachments = json['materials'] ?? json['attachments'];
    if (rawAttachments is Iterable) {
      attachments.addAll(
        rawAttachments
            .whereType<Map<String, dynamic>>()
            .map(AnnouncementAttachmentModel.fromJson),
      );
    }

    return AnnouncementModel(
      id: json['id']?.toString() ?? '',
      classroomId: json['classroomId']?.toString() ?? '',
      content: json['content'] as String? ?? '',
      attachments: attachments,
      isForAll: json['isForAll'] as bool?,
      targetUserIds: targets,
      createdBy: json['createdBy']?.toString(),
      createdByName: json['createdByName'] as String?,
      createdByAvatar: json['createdByAvatar'] as String?,
      createdAt: parseDate(json['createdAt']),
    );
  }
}
