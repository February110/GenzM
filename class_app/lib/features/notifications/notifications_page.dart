import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/notification_model.dart';
import '../assignments/assignment_detail_page.dart';
import '../classrooms/classrooms_page.dart';
import 'notifications_controller.dart';
import '../../data/models/notification_model.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(notificationsControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thông báo',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: const Color(0xFF111827),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, color: Color(0xFF111827)),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFF),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsControllerProvider.notifier).load(),
        child: state.isLoading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: state.items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: state.unread > 0
                            ? () => ref
                                .read(notificationsControllerProvider.notifier)
                                .markAllRead()
                            : null,
                        child: const Text('Đánh dấu tất cả đã đọc'),
                      ),
                    );
                  }
                  final item = state.items[index - 1];
                  final palette = _paletteForType(item.type);
                  final action = _actionForType(item.type);
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _handleTap(context, item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AvatarChip(
                                  text: _initials(item.actorName ?? item.title, fallback: item.type),
                                  color: palette.avatarBg,
                                  icon: action.icon,
                                  iconColor: palette.accent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title.isNotEmpty
                                                  ? item.title
                                                  : 'Thông báo mới',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatRelative(item.createdAt),
                                            style: const TextStyle(
                                              color: Color(0xFF6B7280),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          if (!item.isRead)
                                            const Icon(Icons.brightness_1,
                                                color: Color(0xFF2563EB), size: 8),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (item.message.isNotEmpty)
                                        Text(
                                          item.message,
                                          style: const TextStyle(
                                            color: Color(0xFF4B5563),
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const SizedBox(width: 46),
                                Text(
                                  'Xem chi tiết',
                                  style: TextStyle(
                                    color: palette.accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context, NotificationModel item) async {
    await ref.read(notificationsControllerProvider.notifier).markRead(item.id);

    if (item.assignmentId != null && item.assignmentId!.isNotEmpty) {
      // ignore: use_build_context_synchronously
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AssignmentDetailPage(
            assignmentId: item.assignmentId!,
          ),
        ),
      );
      return;
    }

    if (item.classroomId != null && item.classroomId!.isNotEmpty) {
      // ignore: use_build_context_synchronously
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClassroomDetailPage(
            classroomId: item.classroomId!,
          ),
        ),
      );
    }
  }
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({
    required this.text,
    required this.color,
    this.icon,
    this.iconColor,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: color,
      child: icon != null
          ? Icon(icon, size: 16, color: iconColor ?? Colors.white)
          : Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

String _initials(String title, {String fallback = ''}) {
  final words = title.trim().split(RegExp(r'\\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length >= 2) {
    return (words[0][0] + words[1][0]).toUpperCase();
  }
  if (words.length == 1 && words[0].isNotEmpty) {
    return words[0][0].toUpperCase();
  }
  if (fallback.isNotEmpty) return fallback[0].toUpperCase();
  return '?';
}

String _formatRelative(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date.toLocal());
  if (diff.inSeconds < 45) return '5 giây trước';
  if (diff.inMinutes < 2) return '1 phút';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
  if (diff.inHours < 2) return '1 giờ';
  if (diff.inHours < 24) return '${diff.inHours} giờ';
  if (diff.inDays == 1) return 'Hôm qua';
  if (diff.inDays < 7) return '${diff.inDays} ngày';
  return DateFormat('dd/MM').format(date.toLocal());
}

_Palette _paletteForType(String type) {
  if (type.startsWith('assignment')) {
    return const _Palette(
      accent: Color(0xFF2563EB),
      avatarBg: Color(0xFFE0EDFF),
    );
  }
  if (type.startsWith('announcement')) {
    return const _Palette(
      accent: Color(0xFF10B981),
      avatarBg: Color(0xFFDFF7EC),
    );
  }
  return const _Palette(
    accent: Color(0xFFF59E0B),
    avatarBg: Color(0xFFFFF4E5),
  );
}

_ActionInfo _actionForType(String type) {
  if (type.contains('comment')) {
    return const _ActionInfo(label: 'Viết bình luận', icon: Icons.mode_comment_outlined);
  }
  if (type.startsWith('announcement')) {
    return const _ActionInfo(label: 'Xem chi tiết', icon: Icons.remove_red_eye_outlined);
  }
  if (type.startsWith('assignment-due')) {
    return const _ActionInfo(label: 'Xem hạn nộp', icon: Icons.timer_outlined);
  }
  if (type.startsWith('assignment')) {
    return const _ActionInfo(label: 'Xem chi tiết', icon: Icons.assignment_outlined);
  }
  return const _ActionInfo(label: 'Xem chi tiết', icon: Icons.notifications_active_outlined);
}

class _Palette {
  const _Palette({required this.accent, required this.avatarBg});
  final Color accent;
  final Color avatarBg;
}

class _ActionInfo {
  const _ActionInfo({required this.label, required this.icon});
  final String label;
  final IconData icon;
}
