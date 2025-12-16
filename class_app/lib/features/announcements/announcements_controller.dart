import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../data/models/announcement_model.dart';
import '../../data/repositories/announcement_repository_impl.dart';
import 'announcement_repository.dart';

class AnnouncementsState {
  const AnnouncementsState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<AnnouncementModel> items;
  final bool isLoading;
  final String? errorMessage;

  AnnouncementsState copyWith({
    List<AnnouncementModel>? items,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AnnouncementsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  factory AnnouncementsState.initial() => const AnnouncementsState();
}

class AnnouncementsController extends StateNotifier<AnnouncementsState> {
  AnnouncementsController(this._repository)
    : super(AnnouncementsState.initial());

  final AnnouncementRepository _repository;

  Future<void> load(String classroomId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.listByClassroom(classroomId);
      final enriched = await Future.wait(
        list.map((a) async {
          try {
            final files = await _repository.listMaterials(a.id);
            return a.copyWith(attachments: files);
          } catch (_) {
            return a;
          }
        }),
      );
      state = state.copyWith(items: enriched, isLoading: false);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải thông báo.',
      );
    }
  }

  Future<void> create({
    required String classroomId,
    required String content,
    List<PlatformFile> attachments = const [],
  }) async {
    try {
      await _repository.create(
        classroomId: classroomId,
        content: content,
        attachments: attachments,
      );
      await load(classroomId);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      rethrow;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tạo thông báo.',
      );
      rethrow;
    }
  }

  Future<void> update(String announcementId, String content) async {
    try {
      await _repository.update(announcementId: announcementId, content: content);
      state = state.copyWith(
        items: state.items
            .map(
              (a) => a.id == announcementId
                  ? a.copyWith(content: content)
                  : a,
            )
            .toList(),
        errorMessage: null,
      );
    } on AppException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      rethrow;
    }
  }

  Future<void> delete(String announcementId) async {
    try {
      await _repository.delete(announcementId);
      state = state.copyWith(
        items: state.items.where((a) => a.id != announcementId).toList(),
        errorMessage: null,
      );
    } on AppException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      rethrow;
    }
  }
}

final announcementsControllerProvider =
    StateNotifierProvider.family<
      AnnouncementsController,
      AnnouncementsState,
      String
    >((ref, classroomId) {
      final controller = AnnouncementsController(
        ref.read(announcementRepositoryProvider),
      );
      controller.load(classroomId);
      return controller;
    });
