import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/token_provider.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../core/config/oauth_config.dart';
import '../announcements/announcements_controller.dart';
import '../classrooms/classroom_controller.dart';
import '../classrooms/classroom_detail_provider.dart';
import '../profile/profile_controller.dart';
import 'auth_repository.dart';
import 'models/auth_state.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

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

  Future<void> loginWithGoogle({
    String? clientId,
  }) async {
    final googleClientId = clientId ?? OAuthConfig.googleClientId;
    if (googleClientId.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Chưa cấu hình GOOGLE_CLIENT_ID',
        isLoading: false,
      );
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    final googleSignIn = GoogleSignIn(
      serverClientId: googleClientId,
      scopes: ['email', 'profile'],
    );
    try {
      final account = await googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      if (account.email.isEmpty) {
        throw AppException('Google không cung cấp email.');
      }
      final token = await _repository.loginWithOAuth(
        email: account.email,
        fullName: account.displayName ?? account.email.split('@').first,
        provider: 'google',
        avatar: account.photoUrl,
        providerId: account.id,
      );
      _ref.read(accessTokenProvider.notifier).state = token;
      _ref.invalidate(profileControllerProvider);
      state = state.copyWith(isLoading: false, token: token);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Đăng nhập Google thất bại. Vui lòng thử lại.',
      );
    }
  }

  Future<void> loginWithFacebook() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
      );
      if (result.status != LoginStatus.success || result.accessToken == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final data = await FacebookAuth.instance.getUserData(
        fields: "name,email,picture.width(400)",
      );
      final email = (data['email'] as String?)?.trim();
      final name = data['name'] as String? ?? '';
      final id = data['id']?.toString();
      final avatar = (data['picture']?['data']?['url'] as String?) ?? '';
      if (email == null || email.isEmpty) {
        throw AppException('Facebook không cung cấp email.');
      }
      final token = await _repository.loginWithOAuth(
        email: email,
        fullName: name.isNotEmpty ? name : email.split('@').first,
        provider: 'facebook',
        avatar: avatar.isNotEmpty ? avatar : null,
        providerId: id,
      );
      _ref.read(accessTokenProvider.notifier).state = token;
      _ref.invalidate(profileControllerProvider);
      state = state.copyWith(isLoading: false, token: token);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Đăng nhập Facebook thất bại. Vui lòng thử lại.',
      );
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref.read(authRepositoryProvider), ref);
  },
);
