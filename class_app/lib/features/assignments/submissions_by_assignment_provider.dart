import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/submission_with_grade_model.dart';
import '../../data/repositories/submission_repository_impl.dart';

final submissionsByAssignmentProvider =
    FutureProvider.family<List<SubmissionWithGradeModel>, String>((
      ref,
      assignmentId,
    ) async {
      return ref
          .read(submissionRepositoryProvider)
          .listByAssignment(assignmentId);
    });
