import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_constants.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  });

  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  });

  Future<void> logout();

  Future<UserModel> getProfile();

  Future<void> verifyOtp({
    required String identifier,
    required String otpCode,
    String purpose = 'registration',
  });

  Future<void> resendOtp({
    required String identifier,
    String purpose = 'registration',
  });
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
        data: {'login': email, 'password': password, 'device_name': 'flutter'},
      );
      final data = res.data['data'] ?? res.data;
      return AuthResponseModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  @override
  Future<void> verifyOtp({
    required String identifier,
    required String otpCode,
    String purpose = 'registration',
  }) async {
    try {
      await _dio.post(
        ApiConstants.verifyOtp,
        data: {
          if (identifier.contains('@'))
            'email': identifier
          else
            'phone': identifier,
          'otp_code': otpCode,
          'purpose': purpose,
        },
      );
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  @override
  Future<void> resendOtp({
    required String identifier,
    String purpose = 'registration',
  }) async {
    try {
      await _dio.post(
        ApiConstants.resendOtp,
        data: {
          if (identifier.contains('@'))
            'email': identifier
          else
            'phone': identifier,
          'purpose': purpose,
        },
      );
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
          'full_name': name,
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
      final data = res.data['user'] ?? res.data['data'] ?? res.data;
      return UserModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  Exception _extractException(DioException e) => e.error is Exception
      ? e.error as Exception
      : const ServerException('حدث خطأ غير متوقع');
}
