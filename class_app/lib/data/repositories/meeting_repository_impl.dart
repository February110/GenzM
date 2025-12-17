import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/logger_service.dart';
import '../datasources/meeting_remote_datasource.dart';
import '../models/meeting_join_result.dart';
import '../models/meeting_model.dart';

class MeetingRepository {
  MeetingRepository(this._remote, this._logger);

  final MeetingRemoteDataSource _remote;
  final LoggerService _logger;

  Future<MeetingModel?> getActive(String classroomId) async {
    try {
      return await _remote.getActive(classroomId);
    } catch (error, stackTrace) {
      _logger.log(
        'get active meeting failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<MeetingModel>> getHistory(String classroomId) async {
    try {
      return await _remote.getHistory(classroomId);
    } catch (error, stackTrace) {
      _logger.log(
        'get meeting history failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<MeetingModel> create(String classroomId, {String? title}) {
    return _remote.create(classroomId, title: title);
  }

  Future<MeetingJoinResult> join(String roomCode) {
    return _remote.join(roomCode);
  }

  Future<void> leave(String meetingId) {
    return _remote.leave(meetingId);
  }

  Future<void> endMeeting(String meetingId) {
    return _remote.endMeeting(meetingId);
  }
}

final meetingRepositoryProvider = Provider<MeetingRepository>((ref) {
  return MeetingRepository(
    ref.read(meetingRemoteDataSourceProvider),
    ref.read(loggerProvider),
  );
});
