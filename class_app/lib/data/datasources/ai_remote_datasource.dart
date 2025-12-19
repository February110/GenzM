import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/api_client.dart';
import '../models/ai_quiz_item_model.dart';

class AiRemoteDataSource {
  AiRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<AiQuizItemModel>> generateQuiz({
    required String content,
    int? count,
    String? language,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/ai/generate-quiz',
        data: {
          'content': content,
          if (count != null) 'count': count,
          if (language != null) 'language': language,
        },
      );
      final data = response.data;
      final rawItems = data is List
          ? data
          : (data is Map<String, dynamic> && data['items'] is List
              ? data['items']
              : null);
      final normalized = <dynamic>[];
      if (rawItems is List) {
        normalized.addAll(rawItems);
      }
      return normalized
          .whereType<Map<String, dynamic>>()
          .map(AiQuizItemModel.fromJson)
          .toList();
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
    return 'Không thể tạo câu hỏi, vui lòng thử lại.';
  }
}

final aiRemoteDataSourceProvider = Provider<AiRemoteDataSource>((ref) {
  return AiRemoteDataSource(ref.read(apiClientProvider));
});
