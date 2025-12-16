import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/classroom_detail_model.dart';
import '../../data/repositories/classroom_repository_impl.dart';

final classroomDetailProvider =
    FutureProvider.family<ClassroomDetailModel, String>((ref, classroomId) {
      return ref
          .read(classroomRepositoryProvider)
          .getClassroomDetail(classroomId);
    });
