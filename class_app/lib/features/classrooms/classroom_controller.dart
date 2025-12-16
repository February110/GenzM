import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../data/models/classroom_model.dart';
import '../../data/repositories/classroom_repository_impl.dart';
import 'classroom_repository.dart';
import 'models/classrooms_state.dart';

class ClassroomController extends StateNotifier<ClassroomsState> {
  ClassroomController(this._repository) : super(ClassroomsState.initial());

  final ClassroomRepository _repository;

  Future<void> fetchClassrooms() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _repository.getClassrooms();
      state = state.copyWith(
        items: result,
        isLoading: false,
        errorMessage: null,
        filterMode: ClassFilterMode.all,
        searchQuery: '',
      );
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải danh sách lớp, vui lòng thử lại.',
      );
    }
  }

  Future<void> joinClassroom(String inviteCode) async {
    await _repository.joinClassroom(inviteCode);
    await fetchClassrooms();
  }

  Future<ClassroomModel> createClassroom({
    required String name,
    String? description,
    String? section,
    String? room,
    String? schedule,
  }) async {
    final newCls = await _repository.createClassroom(
      name: name,
      description: description,
      section: section,
      room: room,
      schedule: schedule,
    );
    await fetchClassrooms();
    return newCls;
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(ClassFilterMode mode) {
    state = state.copyWith(filterMode: mode);
  }
}

final classroomControllerProvider =
    StateNotifierProvider<ClassroomController, ClassroomsState>((ref) {
      return ClassroomController(ref.read(classroomRepositoryProvider));
    });
