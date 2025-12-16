import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/logger_service.dart';
import '../models/classroom_detail_model.dart';
import '../datasources/classroom_remote_datasource.dart';
import '../models/classroom_model.dart';
import '../../features/classrooms/classroom_repository.dart';

class ClassroomRepositoryImpl implements ClassroomRepository {
  ClassroomRepositoryImpl(this._remote, this._logger);

  final ClassroomRemoteDataSource _remote;
  final LoggerService _logger;

  @override
  Future<List<ClassroomModel>> getClassrooms() async {
    try {
      return await _remote.fetchClassrooms();
    } catch (error, stackTrace) {
      _logger.log(
        'Fetch classrooms failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> joinClassroom(String inviteCode) {
    return _remote.joinClassroom(inviteCode);
  }

  @override
  Future<ClassroomModel> createClassroom({
    required String name,
    String? description,
    String? section,
    String? room,
    String? schedule,
  }) {
    return _remote.createClassroom(
      name: name,
      description: description,
      section: section,
      room: room,
      schedule: schedule,
    );
  }

  @override
  Future<ClassroomDetailModel> getClassroomDetail(String classroomId) {
    return _remote.fetchClassroomDetail(classroomId);
  }

  @override
  Future<String> changeBanner(String classroomId) {
    return _remote.changeBanner(classroomId);
  }

  @override
  Future<bool> setInviteCodeVisibility(String classroomId, bool visible) {
    return _remote.setInviteCodeVisibility(classroomId, visible);
  }
}

final classroomRepositoryProvider = Provider<ClassroomRepository>((ref) {
  return ClassroomRepositoryImpl(
    ref.read(classroomRemoteDataSourceProvider),
    ref.read(loggerProvider),
  );
});
