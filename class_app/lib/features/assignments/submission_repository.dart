import 'package:file_picker/file_picker.dart';

import '../../data/models/submission_model.dart';
import '../../data/models/submission_with_grade_model.dart';

abstract class SubmissionRepository {
  Future<String> upload(String assignmentId, PlatformFile file);
  Future<List<SubmissionModel>> mySubmissions();
  Future<List<SubmissionWithGradeModel>> listByAssignment(String assignmentId);
}
