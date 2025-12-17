import '../../data/models/notification_model.dart';
import '../../data/datasources/notification_remote_datasource.dart';

abstract class NotificationRepository {
  Future<NotificationFetchResult> fetch({int take});
  Future<void> markRead(String id);
  Future<void> markAllRead();
}
