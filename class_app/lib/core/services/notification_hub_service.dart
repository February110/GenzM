import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_core/signalr_core.dart';

import '../config/app_config.dart';
import '../models/notification_dto.dart';
import 'token_provider.dart';

enum HubStatus { disconnected, connecting, connected }

class NotificationHubManager extends StateNotifier<HubStatus> {
  NotificationHubManager(this._ref) : super(HubStatus.disconnected);

  final Ref _ref;
  HubConnection? _connection;

  Future<void> ensureStarted() async {
    final token = _ref.read(accessTokenProvider);
    if (token == null || token.isEmpty) {
      await stop();
      return;
    }
    if (_connection != null &&
        _connection!.state == HubConnectionState.connected) {
      return;
    }

    final url = '${AppConfig.apiOrigin}/hubs/notifications';
    _connection = HubConnectionBuilder()
        .withUrl(
          url,
          HttpConnectionOptions(
            accessTokenFactory: () async => token,
            skipNegotiation: true,
            transport: HttpTransportType.webSockets,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('NotificationReceived', (List<Object?>? args) {
      if (args == null || args.isEmpty || args.first is! Map) return;
      final dto = NotificationDto.fromJson(
        Map<String, dynamic>.from(args.first as Map),
      );
      _ref.read(notificationEventsProvider.notifier).add(dto);
    });

    _connection!.onclose((_) {
      state = HubStatus.disconnected;
    });

    state = HubStatus.connecting;
    try {
      await _connection!.start();
      state = HubStatus.connected;
    } catch (e) {
      // Giữ trạng thái để người dùng biết chưa kết nối được
      state = HubStatus.disconnected;
      // In lỗi để dễ debug khi không nhận được thông báo
      // ignore: avoid_print
      print('Notification hub start failed: $e');
    }
  }

  Future<void> stop() async {
    if (_connection != null) {
      try {
        await _connection!.stop();
      } catch (_) {}
      _connection = null;
    }
    state = HubStatus.disconnected;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class NotificationEventsNotifier
    extends StateNotifier<List<NotificationDto>> {
  NotificationEventsNotifier() : super(const []);

  void add(NotificationDto dto) {
    state = [...state, dto];
  }
}

final notificationEventsProvider =
    StateNotifierProvider<NotificationEventsNotifier, List<NotificationDto>>(
  (ref) => NotificationEventsNotifier(),
);

final notificationHubManagerProvider =
    StateNotifierProvider<NotificationHubManager, HubStatus>((ref) {
  return NotificationHubManager(ref);
});
