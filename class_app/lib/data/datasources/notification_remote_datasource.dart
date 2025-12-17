import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/api_client.dart';
import '../models/notification_model.dart';

class NotificationRemoteDataSource {
  NotificationRemoteDataSource(this._client);

  final ApiClient _client;

  Future<NotificationFetchResult> fetch({int take = 20}) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/notifications',
        queryParameters: {'take': take},
      );
      final data = response.data ?? <String, dynamic>{};
      final itemsRaw = data['items'] as List<dynamic>? ?? <dynamic>[];
      final items = itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(NotificationModel.fromJson)
          .toList();
      final unread = data['unread'] as int? ?? 0;
      return NotificationFetchResult(unread: unread, items: items);
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _client.post('/notifications/$id/read');
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<void> markAllRead() async {
    try {
      await _client.post('/notifications/read-all');
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  String _extractMessage(DioException error) {
    final message = error.response?.data is Map<String, dynamic>
        ? (error.response?.data['message'] as String?)
        : error.message;
    return message ?? 'Không thể tải thông báo.';
  }
}

class NotificationFetchResult {
  const NotificationFetchResult({
    required this.unread,
    required this.items,
  });

  final int unread;
  final List<NotificationModel> items;
}

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>(
  (ref) => NotificationRemoteDataSource(ref.read(apiClientProvider)),
);
