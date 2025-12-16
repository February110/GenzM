import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/submission_model.dart';
import '../../data/repositories/submission_repository_impl.dart';

final mySubmissionsProvider = FutureProvider<List<SubmissionModel>>((
  ref,
) async {
  return ref.read(submissionRepositoryProvider).mySubmissions();
});
