import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/ai_quiz_item_model.dart';
import '../../data/models/assignment_model.dart';
import '../../data/models/submission_model.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../classrooms/classroom_detail_provider.dart';
import '../profile/profile_controller.dart';
import 'assignments_controller.dart';
import 'assignment_detail_page.dart';
import 'submission_status_provider.dart';

class AssignmentsPage extends ConsumerWidget {
  const AssignmentsPage({super.key, required this.classroomId});

  final String classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assignmentsControllerProvider(classroomId));
    final notifier = ref.read(
      assignmentsControllerProvider(classroomId).notifier,
    );
    final submissionsAsync = ref.watch(mySubmissionsProvider);
    final filter = ref.watch(selectedFilterProvider);
    final profile = ref.watch(profileControllerProvider);
    final detailAsync = ref.watch(classroomDetailProvider(classroomId));
    final detail = detailAsync.valueOrNull;
    final isTeacher =
        profile.user != null &&
        detail?.members.any(
              (m) =>
                  m.userId == profile.user!.id &&
                  (m.role ?? '').toLowerCase().contains('teacher'),
            ) ==
            true;

    final filtered = _filterAssignments(state.items, submissionsAsync, filter);
    final bottomPadding = isTeacher ? 120.0 : 32.0;

    List<Widget> buildContent() {
      final items = <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatusFilterChip(
                label: 'Tất cả',
                selected: filter == _FilterStatus.all,
                onTap: () => _setFilter(_FilterStatus.all, ref),
              ),
              _StatusFilterChip(
                label: 'Chưa nộp',
                selected: filter == _FilterStatus.notSubmitted,
                onTap: () => _setFilter(_FilterStatus.notSubmitted, ref),
              ),
              _StatusFilterChip(
                label: 'Đã nộp',
                selected: filter == _FilterStatus.submitted,
                onTap: () => _setFilter(_FilterStatus.submitted, ref),
              ),
            ],
          ),
        ),
      ];

      if (state.isLoading && state.items.isEmpty) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      } else if (state.errorMessage != null) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Thử lại',
                  onPressed: () => notifier.load(classroomId),
                ),
              ],
            ),
          ),
        );
      } else if (state.items.isEmpty) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: Text('Chưa có bài tập.')),
          ),
        );
      } else {
        for (int i = 0; i < filtered.length; i++) {
          items.addAll([
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AssignmentCard(
                item: filtered[i],
                submissionsAsync: submissionsAsync,
                isTeacher: isTeacher,
                className: detail?.name,
                onEdit: isTeacher
                    ? () => _showCreateBottomSheet(
                        context,
                        notifier,
                        ref,
                        initial: filtered[i],
                        classroomName: detail?.name,
                      )
                    : null,
                onDelete: isTeacher
                    ? () => _confirmDelete(context, notifier, filtered[i].id)
                    : null,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AssignmentDetailPage(assignmentId: filtered[i].id),
                    ),
                  );
                },
              ),
            ),
            if (i != filtered.length - 1) const SizedBox(height: 12),
          ]);
        }
      }

      return items;
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: const Color(0xFF2563EB),
          onRefresh: () => notifier.load(classroomId),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomPadding),
            children: buildContent(),
          ),
        ),
        if (isTeacher)
          Positioned(
            right: 20,
            bottom: 20,
            child: SizedBox(
              height: 56,
              width: 56,
              child: FloatingActionButton(
                heroTag: 'create-assignment-fab',
                backgroundColor: const Color(0xFF2563EB),
                shape: const StadiumBorder(),
                onPressed: () => _showCreateBottomSheet(
                  context,
                  notifier,
                  ref,
                  classroomName: detail?.name,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
      ],
    );
  }

  void _showCreateBottomSheet(
    BuildContext context,
    AssignmentsController notifier,
    WidgetRef ref, {
    AssignmentModel? initial,
    String? classroomName,
  }) {
    final isEditing = initial != null;
    final titleController = TextEditingController(text: initial?.title ?? '');
    final instructionsController = TextEditingController(
      text: initial?.instructions ?? '',
    );
    final aiPromptController = TextEditingController(
      text: initial?.instructions ?? '',
    );
    final aiCountController = TextEditingController(text: '5');
    DateTime? selectedDue = initial?.dueAt?.toLocal();
    final pointsController = TextEditingController(
      text: initial?.maxPoints?.toString() ?? (isEditing ? '' : '100'),
    );
    List<AiQuizItemModel> aiQuizItems = const [];
    String? aiError;
    bool isGeneratingQuiz = false;
    List<PlatformFile> attachments = const [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setState) {
            final aiRepo = ref.read(aiRepositoryProvider);

            String dueLabel() {
              if (selectedDue == null) return 'Chọn ngày và giờ';
              return DateFormat('HH:mm dd/MM/yyyy').format(selectedDue!);
            }

            Future<void> pickDue() async {
              final now = DateTime.now();
              final date = await showDatePicker(
                context: ctx,
                initialDate: selectedDue ?? now,
                firstDate: now.subtract(const Duration(days: 365)),
                lastDate: now.add(const Duration(days: 365 * 5)),
              );
              if (date == null) return;
              if (!ctx.mounted) return;
              final time = await showTimePicker(
                context: ctx,
                initialTime: selectedDue != null
                    ? TimeOfDay.fromDateTime(selectedDue!)
                    : TimeOfDay.now(),
              );
              if (time == null) return;
              setState(() {
                selectedDue = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            }

            Future<void> pickFiles() async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: true,
              );
              if (result == null || result.files.isEmpty) return;
              setState(() {
                attachments = [...attachments, ...result.files];
              });
            }

            Future<void> generateQuiz() async {
              final prompt = aiPromptController.text.trim();
              if (prompt.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Nhập nội dung để AI tạo câu hỏi.')),
                );
                return;
              }
              int? desiredCount;
              final rawCount = aiCountController.text.trim();
              if (rawCount.isNotEmpty) {
                desiredCount = int.tryParse(rawCount);
                if (desiredCount != null) {
                  desiredCount = desiredCount.clamp(3, 15);
                  aiCountController.text = desiredCount.toString();
                }
              }

              setState(() {
                isGeneratingQuiz = true;
                aiError = null;
              });
              try {
                final result = await aiRepo.generateQuiz(
                  content: prompt,
                  count: desiredCount,
                  language: 'vi',
                );
                setState(() {
                  aiQuizItems = result;
                });
                if (ctx.mounted && result.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('AI chưa tạo được câu hỏi, thử lại với nội dung khác.'),
                    ),
                  );
                }
              } on AppException catch (error) {
                setState(() {
                  aiError = error.message;
                  aiQuizItems = const [];
                });
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(error.message)),
                  );
                }
              } catch (error) {
                setState(() {
                  aiError = error.toString();
                  aiQuizItems = const [];
                });
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              } finally {
                if (ctx.mounted) {
                  setState(() => isGeneratingQuiz = false);
                }
              }
            }

            void appendQuizToInstructions() {
              if (aiQuizItems.isEmpty) return;
              final buffer = StringBuffer(instructionsController.text.trim());
              if (buffer.isNotEmpty) buffer.writeln('\n\n');
              const labels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
              for (var i = 0; i < aiQuizItems.length; i++) {
                final item = aiQuizItems[i];
                buffer.writeln('Câu ${i + 1}: ${item.question}');
                for (var j = 0; j < item.options.length; j++) {
                  final label = j < labels.length ? labels[j] : '•';
                  buffer.writeln('$label. ${item.options[j]}');
                }
                buffer.writeln();
              }
              final updated = buffer.toString().trimRight();
              instructionsController.text = updated;
              instructionsController.selection = TextSelection.collapsed(
                offset: updated.length,
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Đã chèn câu hỏi vào mô tả.')),
                );
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
                  left: 16,
                  right: 16,
                  top: (MediaQuery.of(ctx).viewPadding.top > 0
                          ? MediaQuery.of(ctx).viewPadding.top
                          : 16) +
                      16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                          Expanded(
                            child: Text(
                              isEditing
                                  ? 'Chỉnh sửa bài tập'
                                  : 'Tạo bài tập mới',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tiêu đề',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: Bài tập chương 3 - Lịch sử cận đại',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF6F7FB),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mô tả',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: instructionsController,
                        decoration: InputDecoration(
                          hintText:
                              'Nhập hướng dẫn hoặc mô tả chi tiết cho bài tập...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF6F7FB),
                        ),
                        minLines: 4,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    color: Color(0xFF2563EB),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tạo câu hỏi trắc nghiệm bằng AI',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'AI sẽ dựa trên nội dung bạn nhập để sinh câu hỏi 4 lựa chọn, phù hợp để chèn vào mô tả.',
                                        style: TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    aiPromptController.text = instructionsController.text;
                                    aiPromptController.selection = TextSelection.collapsed(
                                      offset: aiPromptController.text.length,
                                    );
                                  },
                                  child: const Text('Dùng mô tả'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: aiPromptController,
                              decoration: InputDecoration(
                                hintText: 'Nhập nội dung/chủ đề để AI tạo câu hỏi...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              minLines: 3,
                              maxLines: 5,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: aiCountController,
                                    decoration: InputDecoration(
                                      labelText: 'Số câu (3-15)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: isGeneratingQuiz ? null : generateQuiz,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    shape: const StadiumBorder(),
                                  ),
                                  icon: isGeneratingQuiz
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.playlist_add_check),
                                  label: Text(isGeneratingQuiz ? 'Đang tạo...' : 'Tạo câu hỏi'),
                                ),
                              ],
                            ),
                            if (aiError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                aiError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (aiQuizItems.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ...aiQuizItems.asMap().entries.map(
                                (e) => _AiQuizPreview(
                                  item: e.value,
                                  index: e.key,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: appendQuizToInstructions,
                                  icon: const Icon(Icons.content_paste_go),
                                  label: const Text('Chèn vào mô tả'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Lớp học',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          color: const Color(0xFFF6F7FB),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                classroomName ?? 'Lớp hiện tại',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const Icon(Icons.lock, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hạn nộp',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: pickDue,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            color: const Color(0xFFF6F7FB),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dueLabel(),
                                  style: TextStyle(
                                    color: selectedDue == null
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Điểm tối đa',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: pointsController,
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: 100',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF6F7FB),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      if (!isEditing) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Tệp đính kèm',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (attachments.isNotEmpty) ...[
                          ...attachments.map(
                            (f) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file,
                                    color: Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      f.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      setState(() {
                                        attachments = attachments
                                            .where((x) => x != f)
                                            .toList();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        OutlinedButton.icon(
                          onPressed: pickFiles,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Đính kèm tệp'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: isEditing ? 'Cập nhật' : 'Giao bài',
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          int? points;
                          if (pointsController.text.isNotEmpty) {
                            points = int.tryParse(pointsController.text.trim());
                          }
                          final instructions = instructionsController.text
                              .trim();
                          final normalizedInstructions = instructions.isEmpty
                              ? null
                              : instructions;

                          if (initial != null) {
                            await notifier.update(
                              classroomId: classroomId,
                              assignmentId: initial.id,
                              title: title,
                              instructions: normalizedInstructions,
                              dueAt: selectedDue,
                              maxPoints: points,
                            );
                          } else {
                            await notifier.create(
                              classroomId: classroomId,
                              title: title,
                              instructions: normalizedInstructions,
                              dueAt: selectedDue,
                              maxPoints: points,
                              attachments: attachments,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    AssignmentsController notifier,
    String assignmentId,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa bài tập?'),
        content: const Text('Bạn chắc chắn muốn xóa bài tập này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              await notifier.delete(classroomId, assignmentId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

class AssignmentCard extends ConsumerWidget {
  const AssignmentCard({
    super.key,
    required this.item,
    required this.submissionsAsync,
    required this.onTap,
    this.isTeacher = false,
    this.onEdit,
    this.onDelete,
    this.className,
  });

  final AssignmentModel item;
  final AsyncValue<List<SubmissionModel>> submissionsAsync;
  final VoidCallback onTap;
  final bool isTeacher;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? className;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _buildStatus(submissionsAsync, item.id);
    final dueText = _formatDue(item.dueAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EDF3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: _LeadingIcon(status),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: SizedBox(
                      height: 72,
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (isTeacher &&
                                    (onEdit != null || onDelete != null))
                                  PopupMenuButton<_AssignmentMenuAction>(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    icon: const Icon(
                                      Icons.more_vert,
                                      size: 20,
                                      color: Color(0xFF6B7280),
                                    ),
                                    onSelected: (action) {
                                      switch (action) {
                                        case _AssignmentMenuAction.edit:
                                          onEdit?.call();
                                          break;
                                        case _AssignmentMenuAction.delete:
                                          onDelete?.call();
                                          break;
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (onEdit != null)
                                        const PopupMenuItem(
                                          value: _AssignmentMenuAction.edit,
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 18),
                                              SizedBox(width: 8),
                                              Text('Sửa'),
                                            ],
                                          ),
                                        ),
                                      if (onDelete != null)
                                        const PopupMenuItem(
                                          value: _AssignmentMenuAction.delete,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Xóa'),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                          if (item.maxPoints != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Tối đa: ${item.maxPoints} điểm',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Divider(
                  color: Color(0xFFE5E7EB),
                  height: 1,
                  thickness: 1,
                ),
              ),

              const SizedBox(height: 6),

              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: status.label.startsWith('Đã')
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dueText ?? 'Không hạn',
                          style: TextStyle(
                            color: status.label.startsWith('Đã')
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE11D48),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _StatusChip(status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiQuizPreview extends StatelessWidget {
  const _AiQuizPreview({required this.item, required this.index});

  final AiQuizItemModel item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final options = item.options;
    final explanation = item.explanation?.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Câu ${index + 1}: ${item.question}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 8),
          if (options.isEmpty)
            const Text(
              'AI chưa trả về phương án.',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            )
          else
            ...options.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == options.length - 1 ? 2 : 6,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${String.fromCharCode(65 + entry.key)}. ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (item.answer.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Đáp án: ${item.answer}',
              style: const TextStyle(
                color: Color(0xFF0EA5E9),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (explanation != null && explanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Giải thích: $explanation',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ],
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

enum _FilterStatus { all, submitted, notSubmitted }

enum _AssignmentMenuAction { edit, delete }

final selectedFilterProvider = StateProvider<_FilterStatus>(
  (ref) => _FilterStatus.all,
);

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2563EB).withValues(alpha: 0.12)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

_StatusInfo _buildStatus(
  AsyncValue<List<SubmissionModel>> asyncSubs,
  String assignmentId,
) {
  return asyncSubs.maybeWhen(
    data: (subs) {
      SubmissionModel? matched;
      for (final s in subs) {
        if (s.assignmentId == assignmentId) {
          matched = s;
          break;
        }
      }
      if (matched == null) {
        return const _StatusInfo(
          'Chưa nộp',
          Color(0xFFEF4444),
          Icons.pending_actions,
        );
      }
      if (matched.grade != null) {
        return _StatusInfo(
          'Đã chấm • ${matched.grade}',
          const Color(0xFF10B981),
          Icons.verified,
          grade: matched.grade?.toString(),
        );
      }
      return const _StatusInfo('Đã nộp', Color(0xFF2563EB), Icons.cloud_done);
    },
    orElse: () =>
        const _StatusInfo('Chưa nộp', Color(0xFFEF4444), Icons.pending_actions),
  );
}

String? _formatDue(DateTime? due) {
  if (due == null) return null;
  final local = due.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return 'Đến hạn: ${DateFormat('HH:mm').format(local)} Hôm nay';
  }
  return 'Đến hạn: ${DateFormat('HH:mm dd/MM').format(local)}';
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon(this.status);
  final _StatusInfo status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        status.icon == Icons.pending_actions
            ? Icons.assignment_outlined
            : status.icon,
        color: status.color,
        size: 26,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final _StatusInfo status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.icon == Icons.pending_actions
                ? Icons.assignment_outlined
                : status.icon,
            size: 16,
            color: status.color,
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: status.color,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

List<AssignmentModel> _filterAssignments(
  List<AssignmentModel> items,
  AsyncValue<List<SubmissionModel>> asyncSubs,
  _FilterStatus status,
) {
  if (status == _FilterStatus.all) return items;
  final subs = asyncSubs.valueOrNull ?? [];
  final submittedIds = subs.map((s) => s.assignmentId).toSet();
  if (status == _FilterStatus.submitted) {
    return items.where((a) => submittedIds.contains(a.id)).toList();
  }
  return items.where((a) => !submittedIds.contains(a.id)).toList();
}

void _setFilter(_FilterStatus status, WidgetRef ref) {
  ref.read(selectedFilterProvider.notifier).state = status;
}
