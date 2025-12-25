import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/classroom_hub_service.dart';
import '../../data/models/announcement_comment_model.dart';
import '../../data/repositories/announcement_repository_impl.dart';
import 'announcement_repository.dart';

class AnnouncementCommentsState {
  const AnnouncementCommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
  });

  final List<AnnouncementCommentModel> comments;
  final bool isLoading;
  final Object? error;

  AnnouncementCommentsState copyWith({
    List<AnnouncementCommentModel>? comments,
    bool? isLoading,
    Object? error,
  }) {
    return AnnouncementCommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AnnouncementCommentsNotifier extends StateNotifier<AnnouncementCommentsState> {
  AnnouncementCommentsNotifier({
    required this.announcementId,
    required this.classroomId,
    required this.repo,
    required this.hubManager,
  }) : super(const AnnouncementCommentsState(isLoading: true)) {
    _init();
  }

  final String announcementId;
  final String classroomId;
  final AnnouncementRepository repo;
  final ClassroomHubManager hubManager;
  
  StreamSubscription<AnnouncementCommentModel>? _subscription;
  Timer? _pollingTimer;
  String? _optimisticCommentId;

  Future<void> _init() async {
    // Setup stream listener TRƯỚC TIÊN để không bỏ lỡ comment nào (ngay cả khi hub chưa connected)
    _subscription = hubManager.announcementCommentStream.listen((newComment) {
      final newAnnouncementId = newComment.announcementId.trim().toLowerCase();
      final targetAnnouncementId = announcementId.trim().toLowerCase();
      print('📨 Realtime comment received: ${newComment.id} for announcement $newAnnouncementId (target: $targetAnnouncementId)');
      if (newAnnouncementId == targetAnnouncementId) {
        print('✅ Processing realtime comment: ${newComment.id}');
        // Xử lý ngay lập tức, không delay
        _handleRealtimeComment(newComment);
      } else {
        print('⏭️ Skipping comment (different announcement)');
      }
    });

    // Join classroom hub để nhận realtime updates (sau khi đã setup listener)
    await hubManager.joinClassroom(classroomId);

    // Load comments ban đầu sau khi đã setup stream và join hub
    // Không await để không block UI, nhưng vẫn fetch để có data ban đầu
    _fetchComments();

    // Polling để đảm bảo sync (giảm tần suất xuống 30 giây vì đã có realtime)
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchComments(),
    );
  }

  Future<void> _fetchComments() async {
    try {
      final data = await repo.listComments(announcementId);
      
      // Nếu có optimistic comment, giữ lại nó trong danh sách
      final currentComments = List<AnnouncementCommentModel>.from(state.comments);
      AnnouncementCommentModel? optimisticComment;
      try {
        optimisticComment = _optimisticCommentId != null
            ? currentComments.firstWhere(
                (c) => c.id == _optimisticCommentId,
              )
            : null;
      } catch (e) {
        // Optimistic comment không tồn tại trong current comments
        optimisticComment = null;
      }
      
      // Merge comments từ server với optimistic comment (nếu có)
      final mergedComments = List<AnnouncementCommentModel>.from(data);
      if (optimisticComment != null) {
        // Kiểm tra xem optimistic comment đã có trong data chưa (theo content và userId)
        final existsInData = data.any((c) => 
          c.content == optimisticComment!.content && 
          c.userId == optimisticComment.userId &&
          c.createdAt.difference(optimisticComment.createdAt).inSeconds.abs() < 10
        );
        if (!existsInData) {
          // Nếu chưa có trong data, thêm optimistic comment vào
          mergedComments.add(optimisticComment);
          print('✅ Keeping optimistic comment during fetch: ${optimisticComment.id}');
        } else {
          print('✅ Optimistic comment found in server data, removing optimistic: ${optimisticComment.id}');
          _optimisticCommentId = null; // Đã có trong server data, không cần optimistic nữa
        }
      }
      
      // Sort lại theo thời gian
      mergedComments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      state = state.copyWith(
        comments: mergedComments,
        isLoading: false,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error,
      );
    }
  }

  void _handleRealtimeComment(AnnouncementCommentModel newComment) {
    final currentComments = List<AnnouncementCommentModel>.from(state.comments);
    
    // Nếu có optimistic comment, thay thế nó bằng comment thật
    if (_optimisticCommentId != null) {
      final optimisticIndex = currentComments.indexWhere((c) => c.id == _optimisticCommentId);
      if (optimisticIndex != -1) {
        // Thay thế optimistic comment bằng comment thật từ server
        currentComments[optimisticIndex] = newComment;
        _optimisticCommentId = null;
        // Sắp xếp lại theo thời gian sau khi thay thế
        currentComments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        state = state.copyWith(comments: currentComments);
        return;
      }
    }

    // Kiểm tra xem comment đã tồn tại chưa (tránh duplicate)
    final exists = currentComments.any((c) => c.id.trim().toLowerCase() == newComment.id.trim().toLowerCase());
    if (!exists) {
      currentComments.add(newComment);
      // Sắp xếp lại theo thời gian
      currentComments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(comments: currentComments);
    }
  }

  // Thêm optimistic comment ngay lập tức
  void addOptimisticComment({
    required String content,
    required String userId,
    required String userName,
    String? userAvatar,
  }) {
    final optimisticId = 'optimistic-${DateTime.now().millisecondsSinceEpoch}';
    _optimisticCommentId = optimisticId;
    
    final optimisticComment = AnnouncementCommentModel(
      id: optimisticId,
      announcementId: announcementId,
      userId: userId,
      content: content,
      createdAt: DateTime.now(),
      userName: userName,
      userAvatar: userAvatar,
    );

    // Thêm comment vào cuối danh sách ngay lập tức (không sort để nó ở cuối)
    final currentComments = List<AnnouncementCommentModel>.from(state.comments);
    currentComments.add(optimisticComment);
    // Không sort ngay, để comment mới hiện ở cuối ngay lập tức
    // Sẽ sort lại khi nhận comment thật từ server
    
    // Update state ngay lập tức (synchronous)
    state = state.copyWith(comments: currentComments);
    
    print('✅ Optimistic comment added: $optimisticId, total comments: ${currentComments.length}');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pollingTimer?.cancel();
    hubManager.leaveClassroom(classroomId);
    super.dispose();
  }
}

final announcementCommentsProvider =
    StateNotifierProvider.autoDispose.family<AnnouncementCommentsNotifier, AnnouncementCommentsState, ({
      String announcementId,
      String classroomId,
    })>((ref, params) {
      final repo = ref.read(announcementRepositoryProvider);
      final hubManager = ref.read(classroomHubManagerProvider.notifier);
      
      return AnnouncementCommentsNotifier(
        announcementId: params.announcementId,
        classroomId: params.classroomId,
        repo: repo,
        hubManager: hubManager,
      );
    });
