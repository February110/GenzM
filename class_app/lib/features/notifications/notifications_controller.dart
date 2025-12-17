import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/notification_dto.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../features/notifications/notification_repository.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.unread = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<NotificationModel> items;
  final int unread;
  final bool isLoading;
  final String? errorMessage;

  NotificationsState copyWith({
    List<NotificationModel>? items,
    int? unread,
    bool? isLoading,
    String? errorMessage,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unread: unread ?? this.unread,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  factory NotificationsState.initial() => const NotificationsState();
}

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._repository) : super(NotificationsState.initial());

  final NotificationRepository _repository;

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _repository.fetch(take: 50);
      state = state.copyWith(
        items: result.items,
        unread: result.unread,
        isLoading: false,
        errorMessage: null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải thông báo.',
      );
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _repository.markRead(id);
      final wasUnread = state.items.any((n) => n.id == id && !n.isRead);
      state = state.copyWith(
        items: state.items
            .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
            .toList(),
        unread: wasUnread && state.unread > 0 ? state.unread - 1 : state.unread,
      );
    } catch (_) {
      // ignore errors for now to avoid breaking UI
    }
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllRead();
      state = state.copyWith(
        items: state.items.map((n) => n.copyWith(isRead: true)).toList(),
        unread: 0,
      );
    } catch (_) {
      // ignore errors for now to avoid breaking UI
    }
  }

  void addRealtime(NotificationDto dto) {
    final incoming = NotificationModel.fromDto(dto);
    final filtered = state.items.where((n) => n.id != incoming.id).toList();
    final updated = [incoming, ...filtered];
    state = state.copyWith(
      items: updated,
      unread: incoming.isRead ? state.unread : state.unread + 1,
    );
  }

  void reset() {
    state = NotificationsState.initial();
  }
}

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  return NotificationsController(ref.read(notificationRepositoryProvider));
});
