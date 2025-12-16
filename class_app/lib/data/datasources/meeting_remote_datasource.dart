import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/api_client.dart';
import '../models/meeting_join_result.dart';
import '../models/meeting_model.dart';

class MeetingRemoteDataSource {
  MeetingRemoteDataSource(this._client);

  final ApiClient _client;

  Future<MeetingModel?> getActive(String classroomId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/meetings/classrooms/$classroomId/active',
      );
      final data = response.data;
      if (data == null) return null;
      return MeetingModel.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<List<MeetingModel>> getHistory(String classroomId) async {
    try {
      final response = await _client.get<List<dynamic>>(
        '/meetings/classrooms/$classroomId/history',
      );
      final data = response.data ?? <dynamic>[];
      return data
          .whereType<Map<String, dynamic>>()
          .map(MeetingModel.fromJson)
          .toList();
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<MeetingModel> create(String classroomId, {String? title}) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/meetings/classrooms/$classroomId',
        data: {'title': title},
      );
      final data = response.data ?? <String, dynamic>{};
      return MeetingModel.fromJson(data);
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<MeetingJoinResult> join(String roomCode) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/meetings/join',
        data: {'roomCode': roomCode},
      );
      final data = response.data ?? <String, dynamic>{};
      final meetingJson = {
        'id': data['id'] ?? data['Id'],
        'roomCode': data['roomCode'] ?? data['RoomCode'] ?? roomCode,
        'title': data['title'] ?? data['Title'],
        'status': data['status'] ?? data['Status'],
        'startedAt': data['startedAt'] ?? data['StartedAt'],
        'endedAt': data['endedAt'] ?? data['EndedAt'],
      };
      final classroomJson = data['classroom'] ?? <String, dynamic>{};
      final members = <MeetingMember>[];
      final rawMembers = classroomJson['Members'] ?? classroomJson['members'];
      if (rawMembers is Iterable) {
        for (final m in rawMembers) {
          if (m is Map<String, dynamic>) {
            members.add(
              MeetingMember(
                userId: m['userId']?.toString() ?? '',
                fullName: m['fullName'] as String? ?? '',
                avatar: m['avatar'] as String?,
              ),
            );
          }
        }
      }
      final classroom = MeetingClassroom(
        id:
            classroomJson['id']?.toString() ??
            classroomJson['Id']?.toString() ??
            '',
        name:
            classroomJson['name'] as String? ??
            classroomJson['Name'] as String? ??
            '',
        members: members,
      );
      final role = data['role']?.toString() ?? '';
      return MeetingJoinResult(
        meeting: MeetingModel.fromJson(meetingJson),
        classroom: classroom,
        role: role,
      );
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
    return 'Không thể tải cuộc họp.';
  }
}

final meetingRemoteDataSourceProvider = Provider<MeetingRemoteDataSource>((
  ref,
) {
  return MeetingRemoteDataSource(ref.read(apiClientProvider));
});
