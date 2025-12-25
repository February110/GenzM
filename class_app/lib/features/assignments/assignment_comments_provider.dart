import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/classroom_hub_service.dart';
import '../../data/models/assignment_comment_model.dart';
import '../../data/repositories/assignment_repository_impl.dart';
import 'assignment_repository.dart';

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

class AssignmentCommentsState {
  const AssignmentCommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
  });

  final List<AssignmentCommentModel> comments;
  final bool isLoading;
  final Object? error;

  AssignmentCommentsState copyWith({
    List<AssignmentCommentModel>? comments,
    bool? isLoading,
    Object? error,
  }) {
    return AssignmentCommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AssignmentCommentsNotifier
    extends StateNotifier<AssignmentCommentsState> {
  AssignmentCommentsNotifier({
    required this.assignmentId,
    required this.studentId,
    required this.repo,
    required this.hubManager,
  }) : super(const AssignmentCommentsState(isLoading: true)) {
    _init();
  }

  final String assignmentId;
  final String? studentId;
  final AssignmentRepository repo;
  final ClassroomHubManager hubManager;

  StreamSubscription<AssignmentCommentModel>? _subscription;

  String get _normalizedAssignmentId => assignmentId.trim().toLowerCase();
  String? get _normalizedStudentId {
    final raw = studentId?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.toLowerCase();
  }

  Future<void> _init() async {
    _subscription =
        hubManager.assignmentCommentStream.listen(_handleRealtimeComment);

    final threadStudentId = _normalizedStudentId;
    if (threadStudentId != null && _normalizedAssignmentId.isNotEmpty) {
      await hubManager.joinAssignmentThread(
        _normalizedAssignmentId,
        threadStudentId,
      );
    }

    await _fetchComments();
  }

  Future<void> refresh() => _fetchComments();

  Future<void> _fetchComments() async {
    try {
      final shouldShowLoading = state.comments.isEmpty;
      if (shouldShowLoading) {
        state = state.copyWith(isLoading: true, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: null);
      }
      final data = await repo.listComments(
        assignmentId,
        studentId: studentId,
      );
      final sorted = [...data]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(
        comments: sorted,
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

  void _handleRealtimeComment(AssignmentCommentModel newComment) {
    final threadStudentId = _normalizedStudentId;
    if (threadStudentId == null || _normalizedAssignmentId.isEmpty) return;
    if (newComment.assignmentId.trim().toLowerCase() !=
        _normalizedAssignmentId) {
      return;
    }
    final incomingStudentId = newComment.targetUserId?.trim().toLowerCase();
    if (incomingStudentId == null || incomingStudentId != threadStudentId) {
      return;
    }
    final current = List<AssignmentCommentModel>.from(state.comments);
    final exists = current.any(
      (c) => c.id.trim().toLowerCase() == newComment.id.trim().toLowerCase(),
    );
    if (exists) return;
    current.add(newComment);
    current.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(comments: current);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    final threadStudentId = _normalizedStudentId;
    if (threadStudentId != null && _normalizedAssignmentId.isNotEmpty) {
      hubManager.leaveAssignmentThread(
        _normalizedAssignmentId,
        threadStudentId,
      );
    }
    super.dispose();
  }
}

final assignmentCommentsProvider = StateNotifierProvider.autoDispose
    .family<AssignmentCommentsNotifier, AssignmentCommentsState,
        AssignmentCommentParams>((ref, params) {
  final repo = ref.read(assignmentRepositoryProvider);
  final hubManager = ref.read(classroomHubManagerProvider.notifier);
  return AssignmentCommentsNotifier(
    assignmentId: params.assignmentId,
    studentId: params.studentId,
    repo: repo,
    hubManager: hubManager,
  );
});
