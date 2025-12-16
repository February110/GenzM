import 'package:file_picker/file_picker.dart';

import '../../data/models/announcement_attachment_model.dart';
import '../../data/models/announcement_comment_model.dart';
import '../../data/models/announcement_model.dart';

abstract class AnnouncementRepository {
  Future<List<AnnouncementModel>> listByClassroom(String classroomId);
  Future<AnnouncementModel> create({
    required String classroomId,
    required String content,
    List<PlatformFile> attachments,
  });
  Future<List<AnnouncementAttachmentModel>> listMaterials(
    String announcementId,
  );
  Future<void> update({
    required String announcementId,
    required String content,
  });
  Future<void> delete(String announcementId);
  Future<List<AnnouncementCommentModel>> listComments(String announcementId);
  Future<AnnouncementCommentModel> addComment({
    required String announcementId,
    required String content,
  });
}
