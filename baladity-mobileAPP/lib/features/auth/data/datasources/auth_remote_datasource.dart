import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_constants.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login({required String email, required String password});

  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  });

  Future<void> logout();

  Future<UserModel> getProfile();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;
  AuthRemoteDataSourceImpl(this._dio);

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      final data = res.data['data'] ?? res.data;
      return AuthResponseModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  @override
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final res = await _dio.post(
        ApiConstants.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'phone': ?phone,
        },
      );
      final data = res.data['data'] ?? res.data;
      return AuthResponseModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  @override
  Future<UserModel> getProfile() async {
    try {
      final res = await _dio.get(ApiConstants.profile);
      final data = res.data['data'] ?? res.data;
      return UserModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  Exception _extractException(DioException e) =>
      e.error is Exception ? e.error as Exception : const ServerException('حدث خطأ غير متوقع');
}
