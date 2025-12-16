import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/api_client.dart';
import '../models/classroom_detail_model.dart';
import '../models/classroom_model.dart';

class ClassroomRemoteDataSource {
  ClassroomRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<ClassroomModel>> fetchClassrooms() async {
    try {
      final response = await _client.get<List<dynamic>>('/classrooms');
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(ClassroomModel.fromJson)
          .toList();
    } on DioException catch (error) {
      final message = _extractMessage(error);
      throw AppException(message, code: error.response?.statusCode?.toString());
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Không thể tải danh sách lớp, vui lòng thử lại.';
  }

  Future<void> joinClassroom(String inviteCode) async {
    try {
      await _client.post<void>(
        '/classrooms/join',
        data: {'inviteCode': inviteCode},
      );
    } on DioException catch (error) {
      final message = _extractMessage(error);
      throw AppException(message, code: error.response?.statusCode?.toString());
    }
  }

  Future<ClassroomModel> createClassroom({
    required String name,
    String? description,
    String? section,
    String? room,
    String? schedule,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/classrooms',
        data: {
          'name': name,
          'description': description,
          'section': section,
          'room': room,
          'schedule': schedule,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      return ClassroomModel.fromJson(data);
    } on DioException catch (error) {
      final message = _extractMessage(error);
      throw AppException(message, code: error.response?.statusCode?.toString());
    }
  }

  Future<ClassroomDetailModel> fetchClassroomDetail(String classroomId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/classrooms/$classroomId',
      );
      final data = response.data ?? <String, dynamic>{};
      return ClassroomDetailModel.fromJson(data);
    } on DioException catch (error) {
      final message = _extractMessage(error);
      throw AppException(message, code: error.response?.statusCode?.toString());
    }
  }

  Future<String> changeBanner(String classroomId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/classrooms/$classroomId/change-banner',
      );
      return response.data?['bannerUrl'] as String? ?? '';
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<bool> setInviteCodeVisibility(String classroomId, bool visible) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/classrooms/$classroomId/invite-code-visibility',
        data: {'visible': visible},
      );
      return response.data?['inviteCodeVisible'] as bool? ?? visible;
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }
}

final classroomRemoteDataSourceProvider = Provider<ClassroomRemoteDataSource>(
  (ref) => ClassroomRemoteDataSource(ref.read(apiClientProvider)),
);
