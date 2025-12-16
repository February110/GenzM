import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/announcement_comment_model.dart';
import '../../data/repositories/announcement_repository_impl.dart';

final announcementCommentsProvider =
    FutureProvider.family<List<AnnouncementCommentModel>, String>((
      ref,
      announcementId,
    ) {
      return ref
          .read(announcementRepositoryProvider)
          .listComments(announcementId);
    });
