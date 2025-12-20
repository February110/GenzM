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
  String? selectedStudentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
    selectedStudentId ??= (showSubmitted && submitted.isNotEmpty
        ? submitted.first.userId
        : !showSubmitted && pendingMembers.isNotEmpty
        ? pendingMembers.first.userId
        : studentMembers.isNotEmpty
        ? studentMembers.first.userId
        : null);

    final filteredSubmitted = submitted
        .where(
          (s) => selectedStudentId == null || s.userId == selectedStudentId,
        )
        .toList();
    final filteredPending = pendingMembers
        .where(
          (m) => selectedStudentId == null || m.userId == selectedStudentId,
        )
        .toList();

    final canGrade = showSubmitted && filteredSubmitted.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.assignment.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(context),
          const SizedBox(height: 12),
          _sectionTitle(
            context,
            'Danh sách lớp',
            count: studentMembers.length,
            trailing: widget.classroomName,
          ),
          const SizedBox(height: 8),
          _chips(
            context,
            submittedCount: submitted.length,
            pendingCount: pendingCount,
          ),
          const SizedBox(height: 12),
          if (submitted.isEmpty && pendingCount == 0)
            Center(
              child: Text(
                'Chưa có học viên trong lớp.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          else ...[
            _studentsScroller(
              submittedUserIds,
              showSubmitted,
              selectedStudentId: selectedStudentId,
              onSelect: (id) {
                setState(() {
                  selectedStudentId = selectedStudentId == id ? null : id;
                });
              },
            ),
            const SizedBox(height: 12),
            if (showSubmitted) ...[
              if (submitted.isEmpty)
                Text(
                  'Chưa có bài đã nộp.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                )
              else
                Column(
                  children: filteredSubmitted
                      .map((s) => _submissionTile(context, s, true))
                      .toList(),
                ),
            ] else ...[
              if (pendingMembers.isEmpty)
                Text(
                  'Không còn học viên chưa nộp.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                )
              else
                Column(
                  children: filteredPending
                      .map((member) => _pendingTile(context, member))
                      .toList(),
                ),
            ],
          ],
          const SizedBox(height: 24),
          _sectionTitle(context, 'Đánh giá & Phản hồi'),
          const SizedBox(height: 8),
          _gradingBox(context, canGrade),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: _actionsBar(context, canGrade),
    );
  }

  Widget _headerCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final due = widget.assignment.dueAt != null
        ? 'Hạn: ${widget.assignment.dueAt!.toLocal().toString().substring(0, 16)}'
        : 'Không hạn';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.assignment.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.assignment.maxPoints != null)
            Text(
              'Tối đa: ${widget.assignment.maxPoints} điểm',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            due,
            style: TextStyle(
              color: colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title, {
    String? trailing,
    int? count,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: colorScheme.onSurface,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _chips(
    BuildContext context, {
    required int submittedCount,
    required int pendingCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _chip(
            context,
            label: 'Đã nộp',
            count: submittedCount,
            selected: showSubmitted,
            onTap: () => setState(() => showSubmitted = true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _chip(
            context,
            label: 'Chưa nộp',
            count: pendingCount,
            selected: !showSubmitted,
            onTap: () => setState(() => showSubmitted = false),
          ),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primary.withValues(alpha: 0.12)
                    : colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: submitted
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  submitted ? 'Đã nộp' : 'Chưa nộp',
                  style: TextStyle(
                    color: submitted
                        ? colorScheme.primary
                        : colorScheme.error,
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
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (submitted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
                color: colorScheme.surfaceVariant,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.insert_drive_file,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName.isNotEmpty ? fileName : 'Bài nộp',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (sizeLabel.isNotEmpty)
                          Text(
                            sizeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.visibility,
                      color: colorScheme.primary,
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
                  foregroundColor: colorScheme.primary,
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

  Widget _gradingBox(BuildContext context, bool enabled) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxPoints = widget.assignment.maxPoints ?? 100;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.75,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.surfaceVariant,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.2),
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
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thang điểm $maxPoints',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/$maxPoints',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
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
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Chỉ nhập điểm khi học viên đã nộp bài.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
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
              children: [
                Icon(Icons.chat_bubble_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Nhận xét',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: colorScheme.onSurface,
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
                fillColor: colorScheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Hãy giữ nhận xét ngắn gọn, cụ thể hành động để học viên cải thiện.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsBar(BuildContext context, bool enabled) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.2),
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
                side: BorderSide(color: theme.dividerColor),
              ),
              child: Text(
                'Lưu nháp',
                style: TextStyle(
                  color: colorScheme.onSurface,
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
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const StadiumBorder(),
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

  Widget _studentsScroller(
    Set<String> submittedUserIds,
    bool showSubmitted, {
    String? selectedStudentId,
    required ValueChanged<String> onSelect,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
          final isSelected = selectedStudentId == m.userId;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    InkWell(
                      onTap: () => onSelect(m.userId),
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : theme.dividerColor,
                            width: isSelected ? 3 : 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: isSelected
                              ? colorScheme.primary
                              : colorScheme.surfaceVariant,
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: isSelected
                                ? colorScheme.primaryContainer
                                : colorScheme.surface,
                            child: _avatarImage(
                              context,
                              m.avatar,
                              name,
                              submitted,
                            ),
                          ),
                        ),
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
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 2,
                            ),
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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
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

  Widget _avatarImage(
    BuildContext context,
    String? url,
    String name,
    bool submitted,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = _initials(name);
    final resolvedUrl = AppConfig.resolveAssetUrl(url);
    final hasAvatar = resolvedUrl.isNotEmpty;
    final isSvg = AppConfig.isSvgUrl(resolvedUrl);

    if (!hasAvatar) {
      return Text(
        initials,
        style: TextStyle(
          color:
              submitted ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
            color:
                submitted ? colorScheme.primary : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'HV';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    final first = parts.first.characters.take(1).toString();
    final last = parts.last.characters.take(1).toString();
    return (first + last).toUpperCase();
  }

  Widget _pendingTile(BuildContext context, ClassroomMember member) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = member.fullName ?? 'Học viên';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Chưa nộp',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Chưa có bài nộp nào. Bạn có thể gửi nhắc nhở.',
            style: TextStyle(
              fontSize: 12.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: member.userId.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AssignmentChatPage(
                            assignmentId: widget.assignment.id,
                            assignmentTitle: widget.assignment.title,
                            isTeacher: true,
                            studentId: member.userId,
                            studentName: member.fullName,
                          ),
                        ),
                      );
                    },
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text(
                'Nhắc nhở',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
