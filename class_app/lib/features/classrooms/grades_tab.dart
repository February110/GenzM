import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/assignment_model.dart';
import '../../data/models/submission_with_grade_model.dart';
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
    if (assignments.isEmpty) {
      return const Center(child: Text('Chưa có bài tập để chấm điểm.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: assignments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final assignment = assignments[index];
        final submissions =
            ref.watch(submissionsByAssignmentProvider(assignment.id));
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (assignment.maxPoints != null)
                      Text(
                        'Tối đa: ${assignment.maxPoints}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
                if (assignment.dueAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Hạn: ${DateFormat('HH:mm dd/MM/yyyy').format(assignment.dueAt!.toLocal())}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: submissions.when(
                    loading: () => const SizedBox(
                      height: 48,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (error, _) => Text(
                      error.toString(),
                      style: const TextStyle(color: Colors.red),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Chưa có bài nộp.',
                            style: TextStyle(color: Color(0xFF6B7280)),
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
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  const _SubmissionRow({required this.submission, this.maxPoints});

  final SubmissionWithGradeModel submission;
  final int? maxPoints;

  @override
  Widget build(BuildContext context) {
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
            backgroundColor: const Color(0xFFE0ECFF),
            child: Text(
              initials,
              style: const TextStyle(
                color: Color(0xFF2563EB),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nộp lúc: $subtitle',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              if (maxPoints != null)
                Text(
                  '/$maxPoints',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
