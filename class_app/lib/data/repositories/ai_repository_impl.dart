import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/logger_service.dart';
import '../datasources/ai_remote_datasource.dart';
import '../models/ai_quiz_item_model.dart';

class AiRepository {
  AiRepository(this._remote, this._logger);

  final AiRemoteDataSource _remote;
  final LoggerService _logger;

  Future<List<AiQuizItemModel>> generateQuiz({
    required String content,
    int? count,
    String? language,
  }) async {
    try {
      return await _remote.generateQuiz(
        content: content,
        count: count,
        language: language,
      );
    } catch (error, stackTrace) {
      _logger.log(
        'generate quiz failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(
    ref.read(aiRemoteDataSourceProvider),
    ref.read(loggerProvider),
  );
});
