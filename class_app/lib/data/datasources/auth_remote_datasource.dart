import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import '../../core/services/api_client.dart';
import '../dto/login_request_dto.dart';
import '../dto/login_response_dto.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final ApiClient _client;

  Future<LoginResponseDto> login(LoginRequestDto payload) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/login',
        data: payload.toJson(),
      );
      final data = response.data ?? <String, dynamic>{};
      return LoginResponseDto.fromJson(data);
    } on DioException catch (error) {
      final message = _extractMessage(error);
      throw AppException(message, code: error.response?.statusCode?.toString());
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Đăng nhập thất bại, vui lòng thử lại.';
  }
}

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.read(apiClientProvider)),
);
