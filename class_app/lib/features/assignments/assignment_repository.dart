import '../../data/models/assignment_model.dart';
import '../../data/models/announcement_attachment_model.dart';
import '../../data/models/assignment_comment_model.dart';
import 'package:file_picker/file_picker.dart';

abstract class AssignmentRepository {
  Future<List<AssignmentModel>> listByClassroom(String classroomId);
  Future<AssignmentModel> getById(String id);
  Future<AssignmentModel> create({
    required String classroomId,
    required String title,
    String? instructions,
    DateTime? dueAt,
    int? maxPoints,
    List<PlatformFile> attachments,
  });
  Future<List<AnnouncementAttachmentModel>> listMaterials(String assignmentId);
  Future<void> delete(String assignmentId);
  Future<AssignmentModel> update({
    required String assignmentId,
    String? title,
    String? instructions,
    DateTime? dueAt,
    int? maxPoints,
  });
  Future<List<AssignmentCommentModel>> listComments(
    String assignmentId, {
    String? studentId,
    int? take,
  });
  Future<AssignmentCommentModel> addComment({
    required String assignmentId,
    required String content,
    String? studentId,
  });
}
