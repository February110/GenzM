import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/assignment_model.dart';
import '../../data/models/submission_with_grade_model.dart';
import '../assignments/assignments_controller.dart';
import '../assignments/submissions_by_assignment_provider.dart';

class GradesTab extends ConsumerWidget {
  const GradesTab({
    super.key,
    required this.classroomId,
    required this.assignments,
  });

  final String classroomId;
  final List<AssignmentModel> assignments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsState =
        ref.watch(assignmentsControllerProvider(classroomId));
    final liveAssignments = assignmentsState.items;
    final visibleAssignments =
        liveAssignments.isNotEmpty ? liveAssignments : assignments;

    if (assignmentsState.isLoading && liveAssignments.isEmpty && assignments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (assignmentsState.errorMessage != null && visibleAssignments.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Text(
          assignmentsState.errorMessage!,
          style: TextStyle(color: colorScheme.error),
        ),
      );
    }

    if (visibleAssignments.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Text(
          'Chưa có bài tập để chấm điểm.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: () async {
        await ref
            .read(assignmentsControllerProvider(classroomId).notifier)
            .load(classroomId);
        final latest =
            ref.read(assignmentsControllerProvider(classroomId)).items;
        await Future.wait(
          latest.map(
            (a) => ref.refresh(
              submissionsByAssignmentProvider(a.id).future,
            ),
          ),
        );
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: visibleAssignments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final assignment = visibleAssignments[index];
          final submissions =
              ref.watch(submissionsByAssignmentProvider(assignment.id));
          return Card(
            elevation: 0,
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          assignment.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (assignment.maxPoints != null)
                        Text(
                          'Tối đa: ${assignment.maxPoints}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                  if (assignment.dueAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Hạn: ${DateFormat('HH:mm dd/MM/yyyy').format(assignment.dueAt!.toLocal())}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: submissions.when(
                      loading: () => const SizedBox(
                        height: 48,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (error, _) => Text(
                        error.toString(),
                        style: TextStyle(color: colorScheme.error),
                      ),
                      data: (items) {
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'Chưa có bài nộp.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            ...items.map(
                              (s) => _SubmissionRow(
                                submission: s,
                                maxPoints: assignment.maxPoints,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  const _SubmissionRow({required this.submission, this.maxPoints});

  final SubmissionWithGradeModel submission;
  final int? maxPoints;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = submission.studentName?.isNotEmpty == true
        ? submission.studentName!
        : submission.email ?? 'Học viên';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'N/A';
    final gradeText = submission.grade != null
        ? '${submission.grade}'
        : 'Chưa chấm';
    final subtitle = DateFormat('HH:mm dd/MM/yyyy')
        .format(submission.submittedAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              initials,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nộp lúc: $subtitle',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                gradeText,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              if (maxPoints != null)
                Text(
                  '/$maxPoints',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
