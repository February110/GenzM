import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/assignment_model.dart';
import '../../data/models/announcement_attachment_model.dart';
import '../../data/models/submission_model.dart';
import '../../data/models/classroom_detail_model.dart';
import '../../data/repositories/assignment_repository_impl.dart';
import '../../data/repositories/submission_repository_impl.dart';
import '../classrooms/classroom_detail_provider.dart';
import '../profile/profile_controller.dart';
import 'assignment_chat_page.dart';
import 'teacher_grading_page.dart';
import 'submission_status_provider.dart';
import 'submissions_by_assignment_provider.dart';

final assignmentDetailProvider =
    FutureProvider.family<AssignmentModel, String>((ref, id) async {
  return ref.read(assignmentRepositoryProvider).getById(id);
});

final assignmentMaterialsProvider =
    FutureProvider.family<List<AnnouncementAttachmentModel>, String>(
  (ref, id) => ref.read(assignmentRepositoryProvider).listMaterials(id),
);

/// Pending file user picked but not yet submitted (keyed by assignment id).
final pendingSubmissionProvider =
    StateProvider.family<PlatformFile?, String>((ref, id) => null);

final Map<String, String> _downloadedMaterialsCache = {};

class AssignmentDetailPage extends ConsumerWidget {
  const AssignmentDetailPage({super.key, required this.assignmentId});

  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final detailAsync = ref.watch(assignmentDetailProvider(assignmentId));
    final submissionsAsync = ref.watch(mySubmissionsProvider);
    final materialsAsync = ref.watch(assignmentMaterialsProvider(assignmentId));
    final profile = ref.watch(profileControllerProvider);

    return detailAsync.when(
      loading: () => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _studentAppBar(ref),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: _studentAppBar(ref),
        body: Center(
          child: Text(
            error.toString(),
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ),
      data: (assignment) {
        final submission = _findSubmission(submissionsAsync, assignment.id);
        final status = _buildStatus(submission);
        final materials = materialsAsync.valueOrNull ?? const [];
        final classroomId = assignment.classroomId;
        final classDetailAsync = classroomId != null
            ? ref.watch(classroomDetailProvider(classroomId))
            : null;
        final isTeacher = classDetailAsync?.valueOrNull?.members.any(
              (m) =>
                  m.userId == profile.user?.id &&
                  (m.role ?? '').toLowerCase().contains('teacher'),
            ) ==
            true;
        if (isTeacher) {
          final subsByAssignment =
              ref.watch(submissionsByAssignmentProvider(assignment.id));
          return subsByAssignment.when(
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Scaffold(
              body: Center(child: Text(err.toString())),
            ),
            data: (subs) => TeacherGradingPage(
              assignment: assignment,
              submissions: subs,
              classroomName: classDetailAsync?.valueOrNull?.name,
              members: classDetailAsync?.valueOrNull?.members ?? const [],
            ),
          );
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: _studentAppBar(ref),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: colorScheme.primary,
                  onRefresh: () async {
                    ref.invalidate(assignmentDetailProvider(assignmentId));
                    ref.invalidate(assignmentMaterialsProvider(assignmentId));
                    ref.invalidate(mySubmissionsProvider);
                    await ref.read(assignmentDetailProvider(assignmentId).future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _headerCard(context, assignment, status),
                      const SizedBox(height: 12),
                      _instructionsCard(context, assignment, materials, materialsAsync),
                      const SizedBox(height: 14),
                      _myWorkCard(
                        context,
                        ref,
                        assignment,
                        submission,
                        status,
                        isTeacher: isTeacher,
                      ),
                      const SizedBox(height: 14),
                      _resultCard(context, assignment, submission),
                    ],
                  ),
                ),
              ),
              _bottomBar(
                context,
                ref,
                assignment,
                submission,
                isTeacher: isTeacher,
                classroomDetail: classDetailAsync?.valueOrNull,
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _studentAppBar(WidgetRef ref) {
    final colorScheme = Theme.of(ref.context).colorScheme;
    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0.5,
      foregroundColor: colorScheme.onSurface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(ref.context),
      ),
      title: const Text(
        'Chi tiết bài tập',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _headerCard(BuildContext context, AssignmentModel a, _StatusInfo status) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dueText = _formatDue(a.dueAt);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          if (a.maxPoints != null)
            Text(
              '${a.maxPoints} điểm',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 8),
          if (dueText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event, size: 16, color: colorScheme.error),
                  const SizedBox(width: 6),
                  Text(
                    'Hạn nộp: $dueText',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _instructionsCard(
    BuildContext context,
    AssignmentModel a,
    List<AnnouncementAttachmentModel> materials,
    AsyncValue<List<AnnouncementAttachmentModel>> materialsAsync,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final content = _plainText(a.instructions);
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
            'Hướng dẫn',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.isNotEmpty ? content : 'Không có hướng dẫn.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          materialsAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, __) => const SizedBox.shrink(),
            data: (_) => materials.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: materials.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, idx) =>
                          _attachmentChip(context, materials[idx]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentChip(BuildContext context, AnnouncementAttachmentModel file) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ext = file.name.split('.').last.toUpperCase();
    final url = file.url ?? '';
    final localPath = _downloadedMaterialsCache[url];
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.insert_drive_file,
              color: colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  ext,
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
              localPath != null && localPath.isNotEmpty
                  ? Icons.open_in_new_rounded
                  : Icons.download,
              size: 18,
              color: colorScheme.primary,
            ),
            onPressed: url.isEmpty
                ? null
                : () {
                    if (localPath != null && localPath.isNotEmpty) {
                      OpenFilex.open(localPath);
                    } else {
                      _downloadFile(context, url, file.name);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(
    BuildContext context,
    String url,
    String name,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$name';
      await Dio().download(url, savePath);
      await OpenFilex.open(savePath);
      _downloadedMaterialsCache[url] = savePath;
      (context as Element).markNeedsBuild();
    } catch (e) {
      debugPrint('Download failed: $e');
    }
  }

  Widget _myWorkCard(
    BuildContext context,
    WidgetRef ref,
    AssignmentModel a,
    SubmissionModel? submission,
    _StatusInfo status, {
    required bool isTeacher,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pendingFile = ref.watch(pendingSubmissionProvider(a.id));

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
          Row(
            children: [
              Text(
                'Bài tập của bạn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              _pill(status.label, status.color.withValues(alpha: 0.12), status.color),
            ],
          ),
          const SizedBox(height: 12),
          if (isTeacher) ...[
            Text(
              'Giáo viên không cần nộp bài. Hãy xem danh sách học viên để chấm.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ] else if (submission != null)
            _submissionTile(context, submission)
          else ...[
            if (pendingFile != null) ...[
              _pendingTile(
                context,
                pendingFile,
                onRemove: () => ref
                    .read(pendingSubmissionProvider(a.id).notifier)
                    .state = null,
              ),
              const SizedBox(height: 12),
            ],
            _uploadPrompt(context, ref, a.id),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _resultCard(BuildContext context, AssignmentModel a, SubmissionModel? submission) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasGrade = submission?.grade != null && a.maxPoints != null;
    final feedback = submission?.feedback;

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
            'Kết quả & Phản hồi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.primaryContainer,
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Điểm số',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        hasGrade ? 'Đã công bố' : 'Chưa có điểm',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasGrade)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        submission!.grade!.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '/${a.maxPoints}',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (feedback != null && feedback.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Nhận xét từ giáo viên',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Text(
                feedback,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar(
    BuildContext context,
    WidgetRef ref,
    AssignmentModel assignment,
    SubmissionModel? submission, {
    required bool isTeacher,
    ClassroomDetailModel? classroomDetail,
  }) {
    if (isTeacher) return const SizedBox.shrink();
    final hasSubmission = submission != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = ref.watch(profileControllerProvider).user;
    String? teacherName;
    if (classroomDetail != null) {
      for (final m in classroomDetail.members) {
        if ((m.role ?? '').toLowerCase().contains('teacher')) {
          teacherName = m.fullName;
          break;
        }
      }
    }
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
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: IconButton(
              icon: Icon(
                Icons.chat_bubble_outline,
                color: colorScheme.primary,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AssignmentChatPage(
                      assignmentId: assignment.id,
                      assignmentTitle: assignment.title,
                      isTeacher: false,
                      studentId: profile?.id,
                      studentName: profile?.name,
                      teacherName: teacherName,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: const StadiumBorder(),
                ),
                onPressed: () => _AssignmentUploader.submit(
                  context,
                  ref,
                  assignment.id,
                ),
                child: Text(
                  hasSubmission ? 'Nộp lại bài' : 'Nộp bài',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusInfo {
  const _StatusInfo(this.label, this.color, this.icon, {this.grade});
  final String label;
  final Color color;
  final IconData icon;
  final String? grade;
}

_StatusInfo _buildStatus(SubmissionModel? submission) {
  if (submission == null) {
    return const _StatusInfo('Chưa nộp', Color(0xFFEF4444), Icons.pending_actions);
  }
  if (submission.grade != null) {
    return _StatusInfo(
      'Đã chấm • ${submission.grade}',
      const Color(0xFF10B981),
      Icons.verified,
      grade: submission.grade?.toString(),
    );
  }
  return const _StatusInfo('Đã nộp', Color(0xFF2563EB), Icons.cloud_done);
}

SubmissionModel? _findSubmission(
  AsyncValue<List<SubmissionModel>> asyncSubs,
  String assignmentId,
) {
  return asyncSubs.maybeWhen(
    data: (subs) {
      for (final s in subs) {
        if (s.assignmentId == assignmentId) return s;
      }
      return null;
    },
    orElse: () => null,
  );
}

String? _formatDue(DateTime? due) {
  if (due == null) return null;
  final local = due.toLocal();
  final now = DateTime.now();
  if (local.year == now.year && local.month == now.month && local.day == now.day) {
    return '${DateFormat('HH:mm').format(local)} hôm nay';
  }
  return DateFormat('HH:mm dd/MM').format(local);
}

Widget _uploadPrompt(
  BuildContext context,
  WidgetRef ref,
  String assignmentId,
) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return InkWell(
    onTap: () => _AssignmentUploader.pickFile(context, ref, assignmentId),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor,
          style: BorderStyle.solid,
          width: 1.5,
        ),
        color: colorScheme.surfaceVariant,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, color: colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            'Thêm tệp hoặc tạo mới',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _pendingTile(
  BuildContext context,
  PlatformFile file, {
  required VoidCallback onRemove,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final sizeMb = file.size > 0
      ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '';
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.dividerColor),
      color: colorScheme.surface,
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: colorScheme.primaryContainer,
          ),
          child: Icon(
            Icons.insert_drive_file,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              if (sizeMb.isNotEmpty)
                Text(
                  sizeMb,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.close,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          onPressed: onRemove,
        ),
      ],
    ),
  );
}

Widget _submissionTile(BuildContext context, SubmissionModel sub) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final submittedAt = DateFormat('HH:mm dd/MM').format(sub.submittedAt.toLocal());
  final sizeMb = sub.fileSize > 0 ? '${(sub.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB' : '';
  final name = sub.fileKey.split('/').last;
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.dividerColor),
      color: colorScheme.surface,
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: colorScheme.errorContainer,
              ),
              child: Icon(
                Icons.picture_as_pdf,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    [sizeMb, 'Đã nộp $submittedAt'].where((s) => s.isNotEmpty).join(' • '),
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
                Icons.close,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor, width: 1.5),
            color: colorScheme.surfaceVariant,
          ),
          child: Column(
            children: [
              Icon(Icons.add, color: colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                'Thêm tệp hoặc tạo mới',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AssignmentUploader {
  static Future<void> pickFile(
    BuildContext context,
    WidgetRef ref,
    String assignmentId,
  ) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    ref.read(pendingSubmissionProvider(assignmentId).notifier).state =
        result.files.first;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã chọn tệp. Nhấn "Nộp bài" để gửi.'),
        ),
      );
    }
  }

  static Future<void> submit(
    BuildContext context,
    WidgetRef ref,
    String assignmentId,
  ) async {
    final pending = ref.read(pendingSubmissionProvider(assignmentId));
    if (pending == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn chưa chọn tệp để nộp.')),
        );
      }
      return;
    }
    try {
      final message = await ref
          .read(submissionRepositoryProvider)
          .upload(assignmentId, pending);
      ref.invalidate(mySubmissionsProvider);
      ref.read(pendingSubmissionProvider(assignmentId).notifier).state = null;
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

String _plainText(String? html) {
  if (html == null || html.isEmpty) return '';
  var text = html;
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</p>\s*<p>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</li>', caseSensitive: false), '\n');
  text = text.replaceAll(
    RegExp(r'</?(ul|ol|li|p|strong|em|b|i)>', caseSensitive: false),
    ' ',
  );
  text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
  text = text.replaceAll('&nbsp;', ' ');
  text = text.replaceAll('&amp;', '&');
  text = text.replaceAll('&lt;', '<').replaceAll('&gt;', '>');
  return text.replaceAll(RegExp(r'\s+\n'), '\n').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}
