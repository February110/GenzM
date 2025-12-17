import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/logger_service.dart';
import '../../features/auth/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../dto/login_request_dto.dart';
import '../dto/login_response_dto.dart';
import '../dto/oauth_user_request_dto.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._logger);

  final AuthRemoteDataSource _remote;
  final LoggerService _logger;

  @override
  Future<String> login({
    required String email,
    required String password,
  }) async {
    try {
      final LoginResponseDto result = await _remote.login(
        LoginRequestDto(email: email, password: password),
      );
      return result.accessToken;
    } on AppException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      _logger.log('Login failed', error: error, stackTrace: stackTrace);
      throw AppException('Unable to login', code: 'login_failed');
    }
  }

  @override
  Future<String> loginWithOAuth({
    required String email,
    required String fullName,
    required String provider,
    String? avatar,
    String? providerId,
  }) async {
    try {
      final LoginResponseDto result = await _remote.syncOAuth(
        OAuthUserRequestDto(
          email: email,
          fullName: fullName,
          provider: provider,
          avatar: avatar,
          providerId: providerId,
        ),
      );
      return result.accessToken;
    } on AppException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      _logger.log('OAuth login failed', error: error, stackTrace: stackTrace);
      throw AppException('Unable to login with $provider', code: 'oauth_login_failed');
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.read(authRemoteDataSourceProvider),
    ref.read(loggerProvider),
  ),
);
