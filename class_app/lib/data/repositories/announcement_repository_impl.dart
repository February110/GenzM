import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/services/logger_service.dart';
import '../datasources/announcement_remote_datasource.dart';
import '../models/announcement_attachment_model.dart';
import '../models/announcement_comment_model.dart';
import '../models/announcement_model.dart';
import '../../features/announcements/announcement_repository.dart';

class AnnouncementRepositoryImpl implements AnnouncementRepository {
  AnnouncementRepositoryImpl(this._remote, this._logger);

  final AnnouncementRemoteDataSource _remote;
  final LoggerService _logger;

  @override
  Future<List<AnnouncementModel>> listByClassroom(String classroomId) async {
    try {
      return await _remote.listByClassroom(classroomId);
    } catch (error, stackTrace) {
      _logger.log(
        'list announcements failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<AnnouncementModel> create({
    required String classroomId,
    required String content,
    List<PlatformFile> attachments = const [],
  }) {
    if (attachments.isNotEmpty) {
      return _remote.createWithFiles(
        classroomId: classroomId,
        content: content,
        files: attachments,
      );
    }
    return _remote.create(classroomId: classroomId, content: content);
  }

  @override
  Future<void> update({
    required String announcementId,
    required String content,
  }) {
    return _remote.update(announcementId: announcementId, content: content);
  }

  @override
  Future<void> delete(String announcementId) {
    return _remote.delete(announcementId);
  }

  @override
  Future<List<AnnouncementAttachmentModel>> listMaterials(
    String announcementId,
  ) {
    return _remote.listMaterials(announcementId);
  }

  @override
  Future<List<AnnouncementCommentModel>> listComments(String announcementId) {
    return _remote.listComments(announcementId);
  }

  @override
  Future<AnnouncementCommentModel> addComment({
    required String announcementId,
    required String content,
  }) {
    return _remote.addComment(announcementId: announcementId, content: content);
  }
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepositoryImpl(
    ref.read(announcementRemoteDataSourceProvider),
    ref.read(loggerProvider),
  );
});
