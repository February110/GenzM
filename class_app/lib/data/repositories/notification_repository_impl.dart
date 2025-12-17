import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/logger_service.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/models/notification_model.dart';
import '../../features/notifications/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._remote, this._logger);

  final NotificationRemoteDataSource _remote;
  final LoggerService _logger;

  @override
  Future<NotificationFetchResult> fetch({int take = 20}) async {
    try {
      return await _remote.fetch(take: take);
    } catch (error, stackTrace) {
      _logger.log(
        'fetch notifications failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _remote.markRead(id);
    } catch (error, stackTrace) {
      _logger.log(
        'mark read failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await _remote.markAllRead();
    } catch (error, stackTrace) {
      _logger.log(
        'mark all read failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    ref.read(notificationRemoteDataSourceProvider),
    ref.read(loggerProvider),
  );
});
