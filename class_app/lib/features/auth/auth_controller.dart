import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/token_provider.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../announcements/announcements_controller.dart';
import '../classrooms/classroom_controller.dart';
import '../classrooms/classroom_detail_provider.dart';
import '../profile/profile_controller.dart';
import 'auth_repository.dart';
import 'models/auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._ref) : super(AuthState.initial());

  final AuthRepository _repository;
  final Ref _ref;

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final token = await _repository.login(email: email, password: password);
      _ref.read(accessTokenProvider.notifier).state = token;
      // load hồ sơ mới sau đăng nhập
      _ref.invalidate(profileControllerProvider);
      state = state.copyWith(
        isLoading: false,
        token: token,
        errorMessage: null,
      );
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Đăng nhập không thành công, vui lòng thử lại.',
      );
    }
  }

  void logout() {
    _ref.read(accessTokenProvider.notifier).state = null;
    _ref.invalidate(profileControllerProvider);
    _ref.invalidate(classroomControllerProvider);
    _ref.invalidate(classroomDetailProvider);
    _ref.invalidate(announcementsControllerProvider);
    state = AuthState.initial();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref.read(authRepositoryProvider), ref);
  },
);
