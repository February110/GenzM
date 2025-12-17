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
    final profile = ref.watch(profileControllerProvider);
    final isTeacherTalkingToStudents = _tabIndex == 0;

    if (profile.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final submissionsAsync = ref.watch(mySubmissionsProvider);
    final threadsAsync = isTeacherTalkingToStudents
        ? ref.watch(teacherAssignmentThreadsProvider)
        : ref.watch(assignmentThreadsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
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
          color: const Color(0xFF2563EB),
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
                color: Colors.white,
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
                            color: const Color(0xFFE5EDFF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isTeacherTalkingToStudents
                                ? Icons.support_agent_outlined
                                : Icons.chat_bubble_outline,
                            color: const Color(0xFF2563EB),
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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (isTeacherTalkingToStudents)
                                          Text(
                                            studentName ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF475569),
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
                                      ? const Color(0xFF475569)
                                      : const Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
    final selected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2563EB).withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF2563EB)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6B7280)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 10),
            Text(
              'Không thể tải tin nhắn',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF6B7280)),
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
