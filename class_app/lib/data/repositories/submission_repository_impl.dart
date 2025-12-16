import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/logger_service.dart';
import '../datasources/submission_remote_datasource.dart';
import '../models/submission_model.dart';
import '../models/submission_with_grade_model.dart';
import '../../features/assignments/submission_repository.dart';

class SubmissionRepositoryImpl implements SubmissionRepository {
  SubmissionRepositoryImpl(this._remote, this._logger);

  final SubmissionRemoteDataSource _remote;
  final LoggerService _logger;

  @override
  Future<String> upload(String assignmentId, PlatformFile file) async {
    try {
      return await _remote.uploadFile(assignmentId, file);
    } catch (error, stackTrace) {
      _logger.log(
        'upload submission failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<SubmissionModel>> mySubmissions() {
    return _remote.mySubmissions();
  }

  @override
  Future<List<SubmissionWithGradeModel>> listByAssignment(
    String assignmentId,
  ) async {
    try {
      return await _remote.listByAssignment(assignmentId);
    } catch (error, stackTrace) {
      _logger.log(
        'list submissions by assignment failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

final submissionRepositoryProvider = Provider<SubmissionRepository>((ref) {
  return SubmissionRepositoryImpl(
    ref.read(submissionRemoteDataSourceProvider),
    ref.read(loggerProvider),
  );
});
