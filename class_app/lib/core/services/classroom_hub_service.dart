import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_core/signalr_core.dart';

import '../config/app_config.dart';
import 'token_provider.dart';
import '../../data/models/announcement_comment_model.dart';
import '../../data/models/assignment_comment_model.dart';

enum ClassroomHubStatus { disconnected, connecting, connected }

class ClassroomHubManager extends StateNotifier<ClassroomHubStatus> {
  ClassroomHubManager(this._ref) : super(ClassroomHubStatus.disconnected);

  final Ref _ref;
  HubConnection? _connection;
  bool _starting = false;
  final Map<String, int> _groupRefCount = {};
  final StreamController<AnnouncementCommentModel> _commentStreamController =
      StreamController<AnnouncementCommentModel>.broadcast();
  final StreamController<AssignmentCommentModel>
      _assignmentCommentStreamController =
      StreamController<AssignmentCommentModel>.broadcast();

  Stream<AnnouncementCommentModel> get announcementCommentStream =>
      _commentStreamController.stream;
  Stream<AssignmentCommentModel> get assignmentCommentStream =>
      _assignmentCommentStreamController.stream;

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
    if (_starting) return;
    _starting = true;

    if (_connection != null) {
      try {
        await _connection!.stop();
      } catch (_) {}
      _connection = null;
    }

    final url = '${AppConfig.apiOrigin}/hubs/classroom';
    final conn = HubConnectionBuilder()
        .withUrl(
          url,
          HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    conn.on('AnnouncementCommentAdded', (args) {
      if (args == null || args.isEmpty || args.first is! Map) {
        print('⚠️ AnnouncementCommentAdded: invalid args');
        return;
      }
      try {
        final raw = Map<String, dynamic>.from(args.first as Map);
        final comment = AnnouncementCommentModel.fromJson(raw);
        if (comment.id.isEmpty || comment.announcementId.isEmpty) {
          print('⚠️ AnnouncementCommentAdded: empty id or announcementId');
          return;
        }
        print('✅ AnnouncementCommentAdded received: ${comment.id} for announcement ${comment.announcementId}');
        _commentStreamController.add(comment);
      } catch (e) {
        print('❌ Error parsing AnnouncementCommentAdded: $e');
      }
    });

    conn.on('CommentAdded', (args) {
      if (args == null || args.isEmpty || args.first is! Map) {
        print('CommentAdded: invalid args');
        return;
      }
      try {
        final raw = Map<String, dynamic>.from(args.first as Map);
        final comment = AssignmentCommentModel.fromJson(raw);
        if (comment.id.isEmpty || comment.assignmentId.isEmpty) {
          print('CommentAdded: empty id or assignmentId');
          return;
        }
        _assignmentCommentStreamController.add(comment);
      } catch (e) {
        print('Error parsing CommentAdded: $e');
      }
    });

    conn.onreconnecting((_) {
      state = ClassroomHubStatus.connecting;
    });

    conn.onreconnected((_) async {
      state = ClassroomHubStatus.connected;
      await _rejoinGroups();
    });

    conn.onclose((_) {
      state = ClassroomHubStatus.disconnected;
    });

    _connection = conn;
    state = ClassroomHubStatus.connecting;
    try {
      await conn.start();
      state = ClassroomHubStatus.connected;
      await _rejoinGroups();
    } catch (e) {
      state = ClassroomHubStatus.disconnected;
      // ignore: avoid_print
      print('Classroom hub start failed: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> joinClassroom(String classroomId) async {
    // Backend gửi group theo Guid.ToString() (lowercase), nên normalize để match.
    final groupId = _classroomGroupId(classroomId);
    await _joinGroup(groupId);
  }

  Future<void> leaveClassroom(String classroomId) async {
    final groupId = _classroomGroupId(classroomId);
    await _leaveGroup(groupId);
  }

  Future<void> joinAssignmentThread(
    String assignmentId,
    String studentId,
  ) async {
    final groupId = _threadGroupId(assignmentId, studentId);
    await _joinGroup(groupId);
  }

  Future<void> leaveAssignmentThread(
    String assignmentId,
    String studentId,
  ) async {
    final groupId = _threadGroupId(assignmentId, studentId);
    await _leaveGroup(groupId);
  }

  Future<void> _rejoinGroups() async {
    if (_connection?.state != HubConnectionState.connected) return;
    final groups = _groupRefCount.keys.toList();
    for (final groupId in groups) {
      try {
        await _connection!.invoke('Join', args: [groupId]);
      } catch (_) {}
    }
  }

  String _classroomGroupId(String classroomId) =>
      classroomId.trim().toLowerCase();

  String _threadGroupId(String assignmentId, String studentId) {
    return '${assignmentId.trim().toLowerCase()}:${studentId.trim().toLowerCase()}';
  }

  Future<void> _joinGroup(String groupId) async {
    if (groupId.isEmpty) return;
    final current = _groupRefCount[groupId] ?? 0;
    _groupRefCount[groupId] = current + 1;
    try {
      // Đảm bảo hub đã started và connected
      await ensureStarted();

      // Đợi đến khi hub connected (nếu đang connecting)
      int retries = 0;
      while (_connection?.state != HubConnectionState.connected &&
          retries < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }

      // Chỉ join nếu chưa join trước đó (current == 0) và hub đã connected
      if (current == 0 &&
          _connection?.state == HubConnectionState.connected) {
        print('Joining hub group: $groupId');
        await _connection!.invoke('Join', args: [groupId]);
        print('Joined hub group: $groupId');
      } else {
        print(
          'Skipping join (already joined or not connected): current=$current, state=${_connection?.state}',
        );
      }
    } catch (e) {
      print('Join hub group failed: $e');
    }
  }

  Future<void> _leaveGroup(String groupId) async {
    if (groupId.isEmpty) return;
    final current = _groupRefCount[groupId];
    if (current == null) return;
    if (current <= 1) {
      _groupRefCount.remove(groupId);
      if (_connection?.state == HubConnectionState.connected) {
        try {
          await _connection!.invoke('Leave', args: [groupId]);
        } catch (_) {}
      }
      return;
    }
    _groupRefCount[groupId] = current - 1;
  }

  Future<void> stop() async {
    if (_connection != null) {
      try {
        await _connection!.stop();
      } catch (_) {}
      _connection = null;
    }
    state = ClassroomHubStatus.disconnected;
  }

  @override
  void dispose() {
    stop();
    _commentStreamController.close();
    _assignmentCommentStreamController.close();
    super.dispose();
  }
}

final classroomHubManagerProvider =
    StateNotifierProvider<ClassroomHubManager, ClassroomHubStatus>((ref) {
  return ClassroomHubManager(ref);
});
