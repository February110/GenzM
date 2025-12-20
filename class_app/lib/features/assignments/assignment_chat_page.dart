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

  AssignmentCommentParams get _params => AssignmentCommentParams(
        assignmentId: widget.assignmentId,
        studentId: widget.isTeacher ? widget.studentId : null,
      );

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
      await ref.read(assignmentRepositoryProvider).addComment(
            assignmentId: widget.assignmentId,
            content: text,
            studentId: widget.isTeacher ? widget.studentId : null,
          );
      ref.invalidate(assignmentCommentsProvider(_params));
      final _ =
          await ref.refresh(assignmentCommentsProvider(_params).future);
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

  Future<void> _refresh() {
    ref.invalidate(assignmentCommentsProvider(_params));
    return ref.refresh(assignmentCommentsProvider(_params).future);
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
    final currentUser = ref.watch(profileControllerProvider).user;
    final commentsAsync = ref.watch(assignmentCommentsProvider(_params));
    final counterpart = widget.isTeacher
        ? (widget.studentName?.isNotEmpty == true ? widget.studentName! : 'Học viên')
        : (widget.teacherName?.isNotEmpty == true ? widget.teacherName! : 'Giáo viên');

    commentsAsync.whenData((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trao đổi bài tập',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              widget.assignmentTitle,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isTeacher ? 'Trao đổi với học viên' : 'Trao đổi với giáo viên',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        counterpart,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
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
              color: const Color(0xFF2563EB),
              child: commentsAsync.when(
                loading: () => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ),
                error: (error, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Không tải được trao đổi.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            error.toString(),
                            style: const TextStyle(color: Color(0xFF6B7280)),
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
                ),
                data: (comments) {
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
                  final list = [...comments]
                    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  if (list.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Chưa có trao đổi nào.\nHãy gửi tin nhắn đầu tiên!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF6B7280)),
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
                      final isMine = c.userId == currentUser?.id;
                      final timeLabel =
                          DateFormat('HH:mm dd/MM').format(c.createdAt.toLocal());
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: isMine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!isMine)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  c.userName?.isNotEmpty == true
                                      ? c.userName!
                                      : 'Người dùng',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                color: isMine
                                    ? const Color(0xFF2563EB)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isMine
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFE5E7EB),
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
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
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
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF2563EB)),
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
                        backgroundColor: const Color(0xFF2563EB),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _sending ? null : _send,
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send, size: 18, color: Colors.white),
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
}
