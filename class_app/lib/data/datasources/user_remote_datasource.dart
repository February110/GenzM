import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/api_client.dart';
import '../models/user_model.dart';

class UserRemoteDataSource {
  UserRemoteDataSource(this._client);

  final ApiClient _client;

  Future<UserModel> getProfile() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/users/me');
      final data = response.data ?? <String, dynamic>{};
      return UserModel(
        id: data['id']?.toString() ?? '',
        email: data['email'] as String? ?? '',
        name: data['fullName'] as String?,
        avatar: data['avatar'] as String?,
        systemRole: data['systemRole'] as String?,
        token: null,
      );
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<void> updateProfile({String? fullName, String? avatar}) async {
    try {
      await _client.put<void>(
        '/users/me',
        data: {'fullName': fullName, 'avatar': avatar},
      );
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.post<void>(
        '/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (error) {
      throw AppException(
        _extractMessage(error),
        code: error.response?.statusCode?.toString(),
      );
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Không thể tải hồ sơ.';
  }
}

final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  return UserRemoteDataSource(ref.read(apiClientProvider));
});
