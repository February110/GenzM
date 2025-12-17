import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/api_client.dart';
import '../models/assignment_model.dart';
import '../models/announcement_attachment_model.dart';
import '../models/assignment_comment_model.dart';

class AssignmentRemoteDataSource {
  AssignmentRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<AssignmentModel>> listByClassroom(String classroomId) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/assignments/classroom/$classroomId',
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AssignmentModel.fromJson)
          .toList();
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<AssignmentModel> getById(String id) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/assignments/$id',
      );
      final data = response.data ?? <String, dynamic>{};
      return AssignmentModel.fromJson(data);
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<AssignmentModel> create({
    required String classroomId,
    required String title,
    String? instructions,
    DateTime? dueAt,
    int? maxPoints,
    List<PlatformFile> attachments = const [],
  }) async {
    try {
      Response<Map<String, dynamic>> response;
      if (attachments.isEmpty) {
        response = await _client.post<Map<String, dynamic>>(
          '/assignments',
          data: {
            'classroomId': classroomId,
            'title': title,
            'instructions': instructions,
            'dueAt': dueAt?.toIso8601String(),
            'maxPoints': maxPoints ?? 100,
          },
        );
      } else {
        final form = FormData();
        form.fields
          ..add(MapEntry('ClassroomId', classroomId))
          ..add(MapEntry('Title', title))
          ..add(MapEntry('Instructions', instructions ?? ''))
          ..add(MapEntry('MaxPoints', (maxPoints ?? 100).toString()));
        if (dueAt != null) {
          form.fields.add(
            MapEntry('DueAt', dueAt.toIso8601String()),
          );
        }
        for (final f in attachments) {
          if (f.path == null) continue;
          form.files.add(
            MapEntry(
              'Files',
              await MultipartFile.fromFile(f.path!, filename: f.name),
            ),
          );
        }
        response = await _client.post<Map<String, dynamic>>(
          '/assignments/with-materials',
          data: form,
          options: Options(contentType: 'multipart/form-data'),
        );
      }
      final data = response.data ?? <String, dynamic>{};
      return AssignmentModel.fromJson(data);
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<List<AnnouncementAttachmentModel>> listMaterials(String id) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/assignments/$id/materials',
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

  Future<void> delete(String id) async {
    try {
      await _client.delete('/assignments/$id');
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<List<AssignmentCommentModel>> listComments(
    String assignmentId, {
    String? studentId,
    int? take,
  }) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/comments/assignment/$assignmentId',
        queryParameters: {
          if (studentId != null) 'studentId': studentId,
          if (take != null) 'take': take,
        },
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AssignmentCommentModel.fromJson)
          .toList();
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<AssignmentCommentModel> addComment({
    required String assignmentId,
    required String content,
    String? studentId,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/comments',
        data: {
          'assignmentId': assignmentId,
          'content': content,
          if (studentId != null) 'studentId': studentId,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      return AssignmentCommentModel.fromJson(data);
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<AssignmentModel> update({
    required String assignmentId,
    String? title,
    String? instructions,
    DateTime? dueAt,
    int? maxPoints,
  }) async {
    try {
      final payload = <String, dynamic>{
        'Title': title,
        'Instructions': instructions,
        'DueAt': dueAt?.toIso8601String(),
        'MaxPoints': maxPoints,
      };
      final response = await _client.put<Map<String, dynamic>>(
        '/assignments/$assignmentId',
        data: payload,
      );
      final data = response.data ?? <String, dynamic>{};
      return AssignmentModel.fromJson(data);
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
    return 'Không thể xử lý yêu cầu.';
  }
}

final assignmentRemoteDataSourceProvider = Provider<AssignmentRemoteDataSource>(
  (ref) {
    return AssignmentRemoteDataSource(ref.read(apiClientProvider));
  },
);
