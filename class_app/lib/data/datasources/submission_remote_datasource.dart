import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/api_client.dart';
import '../models/submission_model.dart';
import '../models/submission_with_grade_model.dart';

class SubmissionRemoteDataSource {
  SubmissionRemoteDataSource(this._client);

  final ApiClient _client;

  Future<String> uploadFile(String assignmentId, PlatformFile file) async {
    if (file.path == null) {
      throw AppException('Tệp không hợp lệ');
    }
    try {
      final multipartFile = await MultipartFile.fromFile(
        file.path!,
        filename: file.name,
      );
      final formData = FormData.fromMap({'file': multipartFile});
      final response = await _client.post<Map<String, dynamic>>(
        '/submissions/$assignmentId/upload',
        data: formData,
      );
      final data = response.data ?? <String, dynamic>{};
      return data['message'] as String? ?? 'Nộp bài thành công';
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
    return 'Không thể nộp bài, vui lòng thử lại.';
  }

  Future<List<SubmissionModel>> mySubmissions() async {
    try {
      final response = await _client.get<List<dynamic>>('/submissions/my');
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(SubmissionModel.fromJson)
          .toList();
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<List<SubmissionWithGradeModel>> listByAssignment(
    String assignmentId,
  ) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/submissions/by-assignment/$assignmentId',
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(SubmissionWithGradeModel.fromJson)
          .toList();
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<String> downloadUrl(String submissionId) async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        '/submissions/$submissionId/download',
      );
      final data = res.data ?? <String, dynamic>{};
      final url = data['downloadUrl'] as String?;
      if (url == null || url.isEmpty) {
        throw AppException('Không lấy được liên kết tải.');
      }
      return url;
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }
}

final submissionRemoteDataSourceProvider = Provider<SubmissionRemoteDataSource>(
  (ref) {
    return SubmissionRemoteDataSource(ref.read(apiClientProvider));
  },
);
