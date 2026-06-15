import 'user_model.dart';

class AuthResponseModel {
  final String token;
  final UserModel user;

  const AuthResponseModel({required this.token, required this.user});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final userJson =
        (json['user'] ?? json['data']?['user']) as Map<String, dynamic>;

    return AuthResponseModel(
      token:
          json['access_token']?.toString() ??
          json['token']?.toString() ??
          json['data']?['token']?.toString() ??
          '',
      user: UserModel.fromJson(userJson),
    );
  }
}
