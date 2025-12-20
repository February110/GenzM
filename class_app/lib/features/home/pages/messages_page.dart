import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../assignments/assignment_chat_page.dart';
import '../../assignments/message_threads_provider.dart';
import '../../profile/profile_controller.dart';
import '../../assignments/submission_status_provider.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  /// 0 = Học viên (vai trò giáo viên trò chuyện với học viên), 1 = Giáo viên (vai trò học viên trò chuyện với giáo viên)
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = ref.watch(profileControllerProvider);
    final isTeacherTalkingToStudents = _tabIndex == 0;

    if (profile.isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final submissionsAsync = ref.watch(mySubmissionsProvider);
    final threadsAsync = isTeacherTalkingToStudents
        ? ref.watch(teacherAssignmentThreadsProvider)
        : ref.watch(assignmentThreadsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        foregroundColor: colorScheme.onSurface,
        title: const Text(
          'Tin nhắn',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _tabSwitcher(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildBody(profile, submissionsAsync, threadsAsync, isTeacherTalkingToStudents),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    ProfileState profile,
    AsyncValue<List<dynamic>> submissionsAsync,
    AsyncValue<List<AssignmentThread>> threadsAsync,
    bool isTeacherTalkingToStudents,
  ) {
    if (profile.user == null) {
      return const _EmptyView(
        title: 'Chưa đăng nhập',
        subtitle: 'Vui lòng đăng nhập để xem tin nhắn.',
        icon: Icons.lock_outline,
      );
    }

    // Học viên: giữ logic kiểm tra đã nộp; Giáo viên: bỏ qua.
    if (!isTeacherTalkingToStudents) {
      return submissionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(mySubmissionsProvider);
          },
        ),
        data: (subs) {
          if (subs.isEmpty) {
            return const _EmptyView(
              title: 'Chưa có tin nhắn',
              subtitle: 'Tin nhắn sẽ xuất hiện sau khi bạn nộp bài và trao đổi với giáo viên.',
              icon: Icons.chat_bubble_outline,
            );
          }
          return _threadsList(threadsAsync, isTeacherTalkingToStudents, profile);
        },
      );
    }

    // Giáo viên (trao đổi với học viên)
    return _threadsList(threadsAsync, isTeacherTalkingToStudents, profile);
  }

  Widget _threadsList(
    AsyncValue<List<AssignmentThread>> threadsAsync,
    bool isTeacherTalkingToStudents,
    ProfileState profile,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return threadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(
        message: error.toString(),
        onRetry: () {
          if (isTeacherTalkingToStudents) {
            ref.invalidate(teacherAssignmentThreadsProvider);
          } else {
            ref.invalidate(mySubmissionsProvider);
            ref.invalidate(assignmentThreadsProvider);
          }
        },
      ),
      data: (threads) {
        if (threads.isEmpty) {
          return _EmptyView(
            title: 'Chưa có tin nhắn',
            subtitle: isTeacherTalkingToStudents
                ? 'Chưa có trao đổi với học viên.'
                : 'Bắt đầu trao đổi từ màn hình bài tập.',
            icon: Icons.chat_bubble_outline,
          );
        }
        return RefreshIndicator(
          color: colorScheme.primary,
                      onRefresh: () async {
                        if (isTeacherTalkingToStudents) {
                          ref.invalidate(teacherAssignmentThreadsProvider);
                          final _ = await ref.refresh(
                            teacherAssignmentThreadsProvider.future,
                          );
                        } else {
                          ref.invalidate(mySubmissionsProvider);
                          ref.invalidate(assignmentThreadsProvider);
                          final _ =
                              await ref.refresh(assignmentThreadsProvider.future);
                        }
                      },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final t = threads[index];
              final last = t.lastComment;
              final timeLabel = last != null
                  ? DateFormat('HH:mm dd/MM').format(last.createdAt.toLocal())
                  : 'Chưa có tin nhắn';
              final preview = last?.content ?? 'Chưa có trao đổi';
              final studentId = isTeacherTalkingToStudents
                  ? t.studentId
                  : profile.user?.id;
              final studentName = isTeacherTalkingToStudents
                  ? (t.studentName?.isNotEmpty == true ? t.studentName : 'Học viên')
                  : profile.user?.name;
              final canOpen = isTeacherTalkingToStudents
                  ? studentId != null
                  : true;

              return Material(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: canOpen
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AssignmentChatPage(
                                assignmentId: t.assignment.id,
                                assignmentTitle: t.assignment.title,
                                isTeacher: isTeacherTalkingToStudents,
                                studentId: studentId,
                                studentName: isTeacherTalkingToStudents ? null : profile.user?.name,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 46,
                          width: 46,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isTeacherTalkingToStudents
                                ? Icons.support_agent_outlined
                                : Icons.chat_bubble_outline,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.assignment.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        if (isTeacherTalkingToStudents)
                                          Text(
                                            studentName ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
            ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: canOpen
                                      ? colorScheme.onSurfaceVariant
                                      : colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _tabSwitcher() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          _tabButton('Học viên', 0),
          _tabButton('Giáo viên', 1),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color:
                  selected ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(height: 10),
            Text(
              'Không thể tải tin nhắn',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
