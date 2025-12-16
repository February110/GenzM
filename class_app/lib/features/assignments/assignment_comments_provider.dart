import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/assignment_comment_model.dart';
import '../../data/repositories/assignment_repository_impl.dart';

class AssignmentCommentParams {
  const AssignmentCommentParams({
    required this.assignmentId,
    this.studentId,
  });

  final String assignmentId;
  final String? studentId;

  @override
  bool operator ==(Object other) {
    return other is AssignmentCommentParams &&
        other.assignmentId == assignmentId &&
        other.studentId == studentId;
  }

  @override
  int get hashCode => Object.hash(assignmentId, studentId);
}

final assignmentCommentsProvider = FutureProvider.autoDispose
    .family<List<AssignmentCommentModel>, AssignmentCommentParams>((ref, params) {
  return ref
      .read(assignmentRepositoryProvider)
      .listComments(params.assignmentId, studentId: params.studentId);
});
