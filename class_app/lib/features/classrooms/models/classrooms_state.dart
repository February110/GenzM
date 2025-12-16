import '../../../data/models/classroom_model.dart';

class ClassroomsState {
  const ClassroomsState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.filterMode = ClassFilterMode.all,
  });

  final List<ClassroomModel> items;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final ClassFilterMode? filterMode;

  ClassroomsState copyWith({
    List<ClassroomModel>? items,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    ClassFilterMode? filterMode,
  }) {
    return ClassroomsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      filterMode: filterMode ?? this.filterMode ?? ClassFilterMode.all,
    );
  }

  factory ClassroomsState.initial() => const ClassroomsState();
}

enum ClassFilterMode { all, teaching, enrolled }
