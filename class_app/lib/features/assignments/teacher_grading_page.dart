import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../data/models/assignment_model.dart';
import '../../data/models/classroom_detail_model.dart';
import '../../data/models/submission_with_grade_model.dart';
import '../../data/repositories/submission_repository_impl.dart';
import 'assignment_chat_page.dart';

class TeacherGradingPage extends ConsumerStatefulWidget {
  const TeacherGradingPage({
    super.key,
    required this.assignment,
    required this.submissions,
    this.classroomName,
    this.members = const [],
  });

  final AssignmentModel assignment;
  final List<SubmissionWithGradeModel> submissions;
  final String? classroomName;
  final List<ClassroomMember> members;

  @override
  ConsumerState<TeacherGradingPage> createState() => _TeacherGradingPageState();
}

class _TeacherGradingPageState extends ConsumerState<TeacherGradingPage> {
  bool showSubmitted = true;

  @override
  Widget build(BuildContext context) {
    // Lọc chỉ học viên (bỏ role teacher)
    final studentMembers = widget.members
        .where((m) => (m.role ?? '').toLowerCase() != 'teacher')
        .toList();
    final submitted = widget.submissions;
    final submittedUserIds = submitted.map((s) => s.userId).toSet();
    final pendingMembers = studentMembers
        .where((m) => !submittedUserIds.contains(m.userId))
        .toList();
    final pendingCount = pendingMembers.length;

    final canGrade = showSubmitted && submitted.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          widget.assignment.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(),
          const SizedBox(height: 12),
          _sectionTitle(
            'Danh sách lớp',
            count: studentMembers.length,
            trailing: widget.classroomName,
          ),
          const SizedBox(height: 8),
          _chips(submittedCount: submitted.length, pendingCount: pendingCount),
          const SizedBox(height: 12),
          if (submitted.isEmpty && pendingCount == 0)
            const Center(
              child: Text(
                'Chưa có học viên trong lớp.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else ...[
            _studentsScroller(submittedUserIds, showSubmitted),
            const SizedBox(height: 12),
            if (showSubmitted)
              submitted.isEmpty
                  ? const Text(
                      'Chưa có bài đã nộp.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    )
                  : Column(
                      children: submitted
                          .map((s) => _submissionTile(context, s, true))
                          .toList(),
                    )
            else
              pendingMembers.isEmpty
                  ? const Text(
                      'Không còn học viên chưa nộp.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    )
                  : Column(children: pendingMembers.map(_pendingTile).toList()),
          ],
          const SizedBox(height: 24),
          _sectionTitle('Đánh giá & Phản hồi'),
          const SizedBox(height: 8),
          _gradingBox(canGrade),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: _actionsBar(canGrade),
    );
  }

  Widget _headerCard() {
    final due = widget.assignment.dueAt != null
        ? 'Hạn: ${widget.assignment.dueAt!.toLocal().toString().substring(0, 16)}'
        : 'Không hạn';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.assignment.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          if (widget.assignment.maxPoints != null)
            Text(
              'Tối đa: ${widget.assignment.maxPoints} điểm',
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            due,
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    String title, {
    String? trailing,
    int? count,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _chips({required int submittedCount, required int pendingCount}) {
    return Row(
      children: [
        Expanded(
          child: _chip(
            label: 'Đã nộp',
            count: submittedCount,
            selected: showSubmitted,
            onTap: () => setState(() => showSubmitted = true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _chip(
            label: 'Chưa nộp',
            count: pendingCount,
            selected: !showSubmitted,
            onTap: () => setState(() => showSubmitted = false),
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2563EB).withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _submissionTile(
    BuildContext context,
    SubmissionWithGradeModel sub,
    bool submitted,
  ) {
    final name = sub.studentName ?? 'Học viên';
    final at = DateFormat('HH:mm dd/MM').format(sub.submittedAt.toLocal());
    final fileName = (sub.fileKey ?? '').split('/').last;
    final sizeLabel = sub.fileSize != null && sub.fileSize! > 0
        ? '${(sub.fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: submitted
                      ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  submitted ? 'Đã nộp' : 'Chưa nộp',
                  style: TextStyle(
                    color: submitted
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            submitted ? 'Nộp lúc $at' : 'Chưa nộp',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
          ),
          if (submitted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                color: const Color(0xFFF8FAFC),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName.isNotEmpty ? fileName : 'Bài nộp',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (sizeLabel.isNotEmpty)
                          Text(
                            sizeLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.visibility,
                      color: Color(0xFF2563EB),
                    ),
                    onPressed: sub.id.isEmpty
                        ? null
                        : () async {
                            try {
                              final repo = ref.read(
                                submissionRepositoryProvider,
                              );
                              final url = await repo.downloadUrl(sub.id);
                              await launchUrl(
                                Uri.parse(url),
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (_) {}
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: sub.userId.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AssignmentChatPage(
                              assignmentId: widget.assignment.id,
                              assignmentTitle: widget.assignment.title,
                              isTeacher: true,
                              studentId: sub.userId,
                              studentName: sub.studentName,
                            ),
                          ),
                        );
                      },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text(
                  'Trao đổi',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gradingBox(bool enabled) {
    final maxPoints = widget.assignment.maxPoints ?? 100;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.75,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Điểm số',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thang điểm $maxPoints',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 66,
                  child: TextFormField(
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/$maxPoints',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            if (!enabled)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: const [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Chỉ nhập điểm khi học viên đã nộp bài.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: const [
                Icon(Icons.chat_bubble_outline, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text(
                  'Nhận xét',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              enabled: enabled,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Nhập nhận xét cho học viên...',
                alignLabelWithHint: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Hãy giữ nhận xét ngắn gọn, cụ thể hành động để học viên cải thiện.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsBar(bool enabled) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
            child: OutlinedButton(
              onPressed: enabled ? () {} : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'Lưu nháp',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: enabled ? () {} : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.send),
              label: const Text(
                'Trả bài',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentsScroller(Set<String> submittedUserIds, bool showSubmitted) {
    final studentMembers = widget.members
        .where((m) => (m.role ?? '').toLowerCase() != 'teacher')
        .where(
          (m) => showSubmitted
              ? submittedUserIds.contains(m.userId)
              : !submittedUserIds.contains(m.userId),
        )
        .toList();
    if (studentMembers.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: List.generate(studentMembers.length, (i) {
          final m = studentMembers[i];
          final submitted = submittedUserIds.contains(m.userId);
          final name = m.fullName ?? 'HV ${i + 1}';
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: submitted
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFCBD5E1),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: submitted
                            ? const Color(0xFFDBEAFE)
                            : const Color(0xFFF1F5F9),
                        child: _avatarImage(m.avatar, name, submitted),
                      ),
                    ),
                    if (submitted)
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 70,
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _avatarImage(String? url, String name, bool submitted) {
    final initials = _initials(name);
    final resolvedUrl = AppConfig.resolveAssetUrl(url);
    final hasAvatar = resolvedUrl.isNotEmpty;
    final isSvg = AppConfig.isSvgUrl(resolvedUrl);

    if (!hasAvatar) {
      return Text(
        initials,
        style: TextStyle(
          color: submitted ? const Color(0xFF1D4ED8) : const Color(0xFF1F2937),
          fontWeight: FontWeight.w800,
        ),
      );
    }

    if (isSvg) {
      return ClipOval(
        child: SvgPicture.network(
          resolvedUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          placeholderBuilder: (_) =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        resolvedUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Text(
          initials,
          style: TextStyle(
            color: submitted
                ? const Color(0xFF2563EB)
                : const Color(0xFF475569),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'HV';
    if (parts.length == 1)
      return parts.first.characters.take(2).toString().toUpperCase();
    final first = parts.first.characters.take(1).toString();
    final last = parts.last.characters.take(1).toString();
    return (first + last).toUpperCase();
  }

  Widget _pendingTile(ClassroomMember member) {
    final name = member.fullName ?? 'Học viên';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Chưa nộp',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Chưa có bài nộp nào. Bạn có thể gửi nhắc nhở.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
