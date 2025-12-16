import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/exceptions/app_exception.dart';
import '../../data/models/assignment_model.dart';
import '../../data/repositories/assignment_repository_impl.dart';
import 'assignment_repository.dart';

class AssignmentsState {
  const AssignmentsState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<AssignmentModel> items;
  final bool isLoading;
  final String? errorMessage;

  AssignmentsState copyWith({
    List<AssignmentModel>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AssignmentsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  factory AssignmentsState.initial() => const AssignmentsState();
}

class AssignmentsController extends StateNotifier<AssignmentsState> {
  AssignmentsController(this._repository) : super(AssignmentsState.initial());

  final AssignmentRepository _repository;

  Future<void> load(String classroomId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.listByClassroom(classroomId);
      state = state.copyWith(items: list, isLoading: false);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải danh sách bài tập.',
      );
    }
  }

  Future<void> create({
    required String classroomId,
    required String title,
    String? instructions,
    DateTime? dueAt,
    int? maxPoints,
    List<PlatformFile> attachments = const [],
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.create(
        classroomId: classroomId,
        title: title,
        instructions: instructions,
        dueAt: dueAt?.toUtc(),
        maxPoints: maxPoints,
        attachments: attachments,
      );
      await load(classroomId);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tạo bài tập.',
      );
    }
  }

  Future<void> delete(String classroomId, String assignmentId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.delete(assignmentId);
      await load(classroomId);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể xoá bài tập.',
      );
    }
  }

  Future<void> update({
    required String classroomId,
    required String assignmentId,
    String? title,
    String? instructions,
    DateTime? dueAt,
    int? maxPoints,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.update(
        assignmentId: assignmentId,
        title: title,
        instructions: instructions,
        dueAt: dueAt?.toUtc(),
        maxPoints: maxPoints,
      );
      await load(classroomId);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể cập nhật bài tập.',
      );
    }
  }
}

final assignmentsControllerProvider =
    StateNotifierProvider.family<
      AssignmentsController,
      AssignmentsState,
      String
    >((ref, classroomId) {
      final controller = AssignmentsController(
        ref.read(assignmentRepositoryProvider),
      );
      controller.load(classroomId);
      return controller;
    });
