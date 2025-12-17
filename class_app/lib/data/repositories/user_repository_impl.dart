import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/logger_service.dart';
import '../datasources/user_remote_datasource.dart';
import '../models/user_model.dart';

class UserRepository {
  UserRepository(this._remote, this._logger);

  final UserRemoteDataSource _remote;
  final LoggerService _logger;

  Future<UserModel> getProfile() async {
    try {
      return await _remote.getProfile();
    } catch (error, stackTrace) {
      _logger.log('get profile failed', error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateProfile({String? fullName, String? avatar}) async {
    try {
      await _remote.updateProfile(fullName: fullName, avatar: avatar);
    } catch (error, stackTrace) {
      _logger.log(
        'update profile failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (error, stackTrace) {
      _logger.log(
        'change password failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    ref.read(userRemoteDataSourceProvider),
    ref.read(loggerProvider),
  );
});
