import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assignment_comment_model.dart';
import '../../data/models/assignment_model.dart';
import '../../data/repositories/assignment_repository_impl.dart';
import '../../data/repositories/classroom_repository_impl.dart';
import '../profile/profile_controller.dart';
import 'submission_status_provider.dart';

class AssignmentThread {
  const AssignmentThread({
    required this.assignment,
    required this.studentId,
    required this.studentName,
    this.lastComment,
  });

  final AssignmentModel assignment;
  final String studentId;
  final String? studentName;
  final AssignmentCommentModel? lastComment;
}

final assignmentThreadsProvider =
    FutureProvider.autoDispose<List<AssignmentThread>>((ref) async {
  final user = ref.read(profileControllerProvider).user;
  if (user == null) return [];
  final assignmentRepo = ref.read(assignmentRepositoryProvider);
  final classroomRepo = ref.read(classroomRepositoryProvider);
  final submissions = await ref.watch(mySubmissionsProvider.future);
  final submittedIds = submissions.map((s) => s.assignmentId).toSet();
  final futures = <Future<void>>[];
  final assignmentsMap = <String, AssignmentModel>{};
  final studentNames = <String, String?>{};

  final classrooms = await classroomRepo.getClassrooms();
  for (final c in classrooms) {
    futures.add(() async {
      final list = await assignmentRepo.listByClassroom(c.id);
      for (final a in list) {
        assignmentsMap[a.id] = a;
      }
      final detail = await classroomRepo.getClassroomDetail(c.id);
      for (final m in detail.members) {
        studentNames[m.userId] = m.fullName;
      }
    }());
  }
  await Future.wait(futures);

  // Bổ sung các bài đã nộp nhưng (hi hữu) không lấy được qua lớp.
  for (final id in submittedIds) {
    if (!assignmentsMap.containsKey(id)) {
      assignmentsMap[id] = await assignmentRepo.getById(id);
    }
  }

  final threadsFutures = <Future<List<AssignmentThread>>>[];
  for (final a in assignmentsMap.values) {
    threadsFutures.add(() async {
      final comments = await assignmentRepo.listComments(
        a.id,
        studentId: user.id,
        take: 50,
      );
      final grouped = <String, AssignmentCommentModel>{};
      for (final cmt in comments) {
        final sid = cmt.targetUserId ?? user.id;
        final existing = grouped[sid];
        if (existing == null || cmt.createdAt.isAfter(existing.createdAt)) {
          grouped[sid] = cmt;
        }
      }
      final result = <AssignmentThread>[];
      for (final entry in grouped.entries) {
        final sid = entry.key;
        result.add(
          AssignmentThread(
            assignment: a,
            studentId: sid,
            studentName: studentNames[sid],
            lastComment: entry.value,
          ),
        );
      }
      return result;
    }());
  }

  final threads = (await Future.wait(threadsFutures))
      .expand((x) => x)
      .whereType<AssignmentThread>()
      .toList();
  threads.sort((a, b) {
    final aTime = a.lastComment?.createdAt;
    final bTime = b.lastComment?.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });
  return threads;
});

/// Thread list dành cho giáo viên: gom tất cả bài tập thuộc lớp mà user là giáo viên,
/// lấy comment mới nhất (có target học viên).
final teacherAssignmentThreadsProvider =
    FutureProvider.autoDispose<List<AssignmentThread>>((ref) async {
  final user = ref.read(profileControllerProvider).user;
  if (user == null) return [];
  final assignmentRepo = ref.read(assignmentRepositoryProvider);
  final classroomRepo = ref.read(classroomRepositoryProvider);

  final classrooms = await classroomRepo.getClassrooms();
  final teacherClasses = classrooms
      .where((c) => (c.role ?? '').toLowerCase().contains('teacher'))
      .toList();
  if (teacherClasses.isEmpty) return [];

  final assignments = <AssignmentModel>[];
  await Future.wait(
    teacherClasses.map((c) async {
      final list = await assignmentRepo.listByClassroom(c.id);
      assignments.addAll(list);
    }),
  );

  final futures = assignments.map((a) async {
    final comments = await assignmentRepo.listComments(
      a.id,
      take: 1,
    );
    if (comments.isEmpty) return null;
    final last = comments.first;
    if (last.targetUserId == null) return null;
    return AssignmentThread(
      assignment: a,
      studentId: last.targetUserId ?? '',
      studentName: last.userName,
      lastComment: last,
    );
  });

  final threads =
      (await Future.wait(futures)).whereType<AssignmentThread>().toList();
  threads.sort((a, b) {
    final aTime = a.lastComment?.createdAt;
    final bTime = b.lastComment?.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });

  return threads;
});
