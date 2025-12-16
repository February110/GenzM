import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/api_client.dart';
import '../models/announcement_comment_model.dart';
import '../models/announcement_model.dart';
import '../models/announcement_attachment_model.dart';

class AnnouncementRemoteDataSource {
  AnnouncementRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<AnnouncementModel>> listByClassroom(String classroomId) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/announcements/classroom/$classroomId',
        queryParameters: {'take': 50},
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AnnouncementModel.fromJson)
          .toList();
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<AnnouncementModel> create({
    required String classroomId,
    required String content,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/announcements',
        data: {
          'classroomId': classroomId,
          'content': content,
          'allStudents': true,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      return AnnouncementModel.fromJson(data);
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<void> update({
    required String announcementId,
    required String content,
  }) async {
    try {
      await _client.put<void>(
        '/announcements/$announcementId',
        data: {'content': content},
      );
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<void> delete(String announcementId) async {
    try {
      await _client.delete<void>('/announcements/$announcementId');
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<AnnouncementModel> createWithFiles({
    required String classroomId,
    required String content,
    List<PlatformFile> files = const [],
  }) async {
    try {
      final formData = FormData();
      formData.fields
        ..add(MapEntry('ClassroomId', classroomId))
        ..add(MapEntry('Content', content))
        ..add(const MapEntry('AllStudents', 'true'));

      for (final f in files) {
        if (f.path == null) continue;
        formData.files.add(
          MapEntry(
            'Files',
            await MultipartFile.fromFile(
              f.path!,
              filename: f.name,
            ),
          ),
        );
      }

      final response = await _client.post<Map<String, dynamic>>(
        '/announcements/with-materials',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = response.data ?? <String, dynamic>{};
      return AnnouncementModel.fromJson(data);
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<List<AnnouncementCommentModel>> listComments(
    String announcementId,
  ) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/announcements/$announcementId/comments',
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AnnouncementCommentModel.fromJson)
          .toList();
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<AnnouncementCommentModel> addComment({
    required String announcementId,
    required String content,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/announcements/$announcementId/comments',
        data: {'content': content},
      );
      final data = response.data ?? <String, dynamic>{};
      return AnnouncementCommentModel.fromJson(data);
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Không thể tải thông báo.';
  }

  Future<List<AnnouncementAttachmentModel>> listMaterials(
    String announcementId,
  ) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/announcements/$announcementId/materials',
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AnnouncementAttachmentModel.fromJson)
          .toList();
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }
}

final announcementRemoteDataSourceProvider =
    Provider<AnnouncementRemoteDataSource>((ref) {
      return AnnouncementRemoteDataSource(ref.read(apiClientProvider));
    });
