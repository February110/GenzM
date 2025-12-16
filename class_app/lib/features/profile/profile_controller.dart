import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository_impl.dart';

class ProfileState {
  const ProfileState({this.user, this.isLoading = false, this.errorMessage});

  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  ProfileState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  factory ProfileState.initial() => const ProfileState();
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._repository) : super(ProfileState.initial());

  final UserRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.getProfile();
      state = state.copyWith(user: user, isLoading: false);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải hồ sơ.',
      );
    }
  }

  Future<void> update({String? fullName, String? avatar}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updateProfile(fullName: fullName, avatar: avatar);
      await load();
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể cập nhật hồ sơ.',
      );
    }
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      final controller = ProfileController(ref.read(userRepositoryProvider));
      controller.load();
      return controller;
    });
