import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/assignment_repository_impl.dart';
import '../profile/profile_controller.dart';
import 'assignment_comments_provider.dart';

class AssignmentChatPage extends ConsumerStatefulWidget {
  const AssignmentChatPage({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.isTeacher,
    this.studentId,
    this.studentName,
    this.teacherName,
  });

  final String assignmentId;
  final String assignmentTitle;
  final bool isTeacher;
  final String? studentId;
  final String? studentName;
  final String? teacherName;

  @override
  ConsumerState<AssignmentChatPage> createState() => _AssignmentChatPageState();
}

class _AssignmentChatPageState extends ConsumerState<AssignmentChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  AssignmentCommentParams _buildParams(String? currentUserId) {
    return AssignmentCommentParams(
      assignmentId: widget.assignmentId,
      studentId: widget.isTeacher ? widget.studentId : currentUserId,
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (widget.isTeacher && (widget.studentId == null || widget.studentId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn học viên để trao đổi.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final currentUser = ref.read(profileControllerProvider).user;
      final params = _buildParams(currentUser?.id);
      await ref.read(assignmentRepositoryProvider).addComment(
            assignmentId: widget.assignmentId,
            content: text,
            studentId: widget.isTeacher ? widget.studentId : null,
          );
      await ref.read(assignmentCommentsProvider(params).notifier).refresh();
      _controller.clear();
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refresh() async {
    final currentUser = ref.read(profileControllerProvider).user;
    final params = _buildParams(currentUser?.id);
    await ref.read(assignmentCommentsProvider(params).notifier).refresh();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentUser = ref.watch(profileControllerProvider).user;
    final params = _buildParams(currentUser?.id);
    final commentsState = ref.watch(assignmentCommentsProvider(params));
    final counterpart = widget.isTeacher
        ? (widget.studentName?.isNotEmpty == true ? widget.studentName! : 'Học viên')
        : (widget.teacherName?.isNotEmpty == true ? widget.teacherName! : 'Giáo viên');

    ref.listen(assignmentCommentsProvider(params), (prev, next) {
      final prevCount = prev?.comments.length ?? 0;
      if (next.comments.length > prevCount) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        foregroundColor: colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trao đổi bài tập',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              widget.assignmentTitle,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isTeacher ? 'Trao đổi với học viên' : 'Trao đổi với giáo viên',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        counterpart,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: colorScheme.primary,
              child: _buildCommentsBody(
                commentsState,
                currentUser?.id,
                theme,
                colorScheme,
              ),
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        filled: true,
                        fillColor: colorScheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colorScheme.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      enabled: !_sending,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 46,
                    width: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: colorScheme.primary,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _sending ? null : _send,
                      child: _sending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.send,
                              size: 18,
                              color: colorScheme.onPrimary,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsBody(
    AssignmentCommentsState commentsState,
    String? currentUserId,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (commentsState.isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    final error = commentsState.error;
    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không tải được trao đổi.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  error.toString(),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (widget.isTeacher &&
        (widget.studentId == null || widget.studentId!.isEmpty)) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chọn một học viên để bắt đầu trao đổi.'),
          ),
        ],
      );
    }

    final list = [...commentsState.comments]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Chưa có trao đổi nào.\nHãy gửi tin nhắn đầu tiên!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (_, index) {
        final c = list[index];
        final isMine = c.userId == currentUserId;
        final timeLabel =
            DateFormat('HH:mm dd/MM').format(c.createdAt.toLocal());
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    c.userName?.isNotEmpty == true ? c.userName! : 'Người dùng',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: isMine ? colorScheme.primary : colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isMine ? colorScheme.primary : theme.dividerColor,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  c.content,
                  style: TextStyle(
                    color: isMine
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
