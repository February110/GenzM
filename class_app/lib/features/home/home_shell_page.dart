import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../classrooms/classrooms_page.dart';
import 'pages/feed_page.dart';
import 'pages/messages_page.dart';
import 'pages/schedule_page.dart';
import '../../core/services/notification_hub_service.dart';
import '../../core/services/permission_service.dart';
import '../profile/profile_controller.dart';
import '../assignments/assignments_controller.dart';
import '../assignments/assignment_detail_page.dart';
import '../announcements/announcements_controller.dart';
import '../notifications/notifications_controller.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key});

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  int _index = 0;

  final List<Widget> _pages = const <Widget>[
    FeedPage(),
    ClassroomsPage(),
    SchedulePage(),
    MessagesPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(permissionServiceProvider).requestEssentialPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    ref.listen(profileControllerProvider, (prev, next) {
      if (next.user != null) {
        ref.read(notificationHubManagerProvider.notifier).ensureStarted();
        ref.read(notificationsControllerProvider.notifier).load();
      } else {
        ref.read(notificationHubManagerProvider.notifier).stop();
        ref.read(notificationsControllerProvider.notifier).reset();
      }
    });

    ref.listen(notificationEventsProvider, (prev, next) {
      if (!mounted) return;
      if (next.isEmpty || (prev != null && prev.length == next.length)) return;
      final last = next.last;
      ref.read(notificationsControllerProvider.notifier).addRealtime(last);
      if (last.classroomId != null && last.classroomId!.isNotEmpty) {
        ref
            .invalidate(announcementsControllerProvider(last.classroomId!));
        ref
            .invalidate(assignmentsControllerProvider(last.classroomId!));
      }
      if (last.assignmentId != null && last.assignmentId!.isNotEmpty) {
        ref.invalidate(assignmentDetailProvider(last.assignmentId!));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${last.title}: ${last.message}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        onTap: (value) => setState(() => _index = value),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: 'Bảng tin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.class_outlined),
            label: 'Lớp học',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            label: 'Lịch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Tin nhắn',
          ),
        ],
      ),
    );
  }
}
