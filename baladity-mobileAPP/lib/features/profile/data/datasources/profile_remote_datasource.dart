import 'package:dio/dio.dart';
import '../../../../core/network/api_constants.dart';
import '../../../auth/data/models/user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> getProfile();
  Future<UserModel> updateUsername({required String name});
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  });
  Future<UserModel> updateProfileImage({required String imagePath});
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio _dio;
  ProfileRemoteDataSourceImpl(this._dio);

  @override
  Future<UserModel> getProfile() async {
    final res = await _dio.get(ApiConstants.userProfile);
    final data = res.data['data'] ?? res.data;
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<UserModel> updateUsername({required String name}) async {
    final res = await _dio.put(
      ApiConstants.updateName,
      data: {'name': name},
    );
    final data = res.data['data'] ?? res.data;
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    await _dio.put(
      ApiConstants.changePassword,
      data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPasswordConfirmation,
      },
    );
  }

  @override
  Future<UserModel> updateProfileImage({required String imagePath}) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        imagePath,
        filename: imagePath.split('/').last,
      ),
    });
    final res = await _dio.post(
      ApiConstants.updateProfileImage,
      data: formData,
    );
    final data = res.data['data'] ?? res.data;
    return UserModel.fromJson(data as Map<String, dynamic>);
  }
}
