import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/services/logger_service.dart';
import '../datasources/assignment_remote_datasource.dart';
import '../models/assignment_model.dart';
import '../models/announcement_attachment_model.dart';
import '../models/assignment_comment_model.dart';
import '../../features/assignments/assignment_repository.dart';

class AssignmentRepositoryImpl implements AssignmentRepository {
  AssignmentRepositoryImpl(this._remote, this._logger);

  final AssignmentRemoteDataSource _remote;
  final LoggerService _logger;

  @override
  Future<List<AssignmentModel>> listByClassroom(String classroomId) async {
    try {
      return await _remote.listByClassroom(classroomId);
    } catch (error, stackTrace) {
      _logger.log(
        'list assignments failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<AssignmentModel> getById(String id) {
    return _remote.getById(id);
  }

  @override
  Future<AssignmentModel> create({
    required String classroomId,
    required String title,
    String? instructions,
    DateTime? dueAt,
    int? maxPoints,
    List<PlatformFile> attachments = const [],
  }) {
    return _remote.create(
      classroomId: classroomId,
      title: title,
      instructions: instructions,
      dueAt: dueAt,
      maxPoints: maxPoints,
      attachments: attachments,
    );
  }

  @override
  Future<List<AnnouncementAttachmentModel>> listMaterials(
      String assignmentId) async {
    try {
      return await _remote.listMaterials(assignmentId);
    } catch (error, stackTrace) {
      _logger.log(
        'list assignment materials failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> delete(String assignmentId) {
    return _remote.delete(assignmentId);
  }

  @override
  Future<AssignmentModel> update({
    required String assignmentId,
    String? title,
    String? instructions,
    DateTime? dueAt,
    int? maxPoints,
  }) {
    return _remote.update(
      assignmentId: assignmentId,
      title: title,
      instructions: instructions,
      dueAt: dueAt,
      maxPoints: maxPoints,
    );
  }

  @override
  Future<List<AssignmentCommentModel>> listComments(
    String assignmentId, {
    String? studentId,
    int? take,
  }) async {
    try {
      return await _remote.listComments(
        assignmentId,
        studentId: studentId,
        take: take,
      );
    } catch (error, stackTrace) {
      _logger.log(
        'list assignment comments failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<AssignmentCommentModel> addComment({
    required String assignmentId,
    required String content,
    String? studentId,
  }) {
    return _remote.addComment(
      assignmentId: assignmentId,
      content: content,
      studentId: studentId,
    );
  }
}

final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  return AssignmentRepositoryImpl(
    ref.read(assignmentRemoteDataSourceProvider),
    ref.read(loggerProvider),
  );
});
