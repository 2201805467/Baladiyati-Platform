import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps FlutterSecureStorage for auth token management.
class TokenStorage {
  TokenStorage()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _userRoleKey = 'user_role';
  static const _departmentNameKey = 'department_name';

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> saveUserId(String id) =>
      _storage.write(key: _userIdKey, value: id);

  Future<String?> getUserId() => _storage.read(key: _userIdKey);

  Future<void> saveUserRole(String? role) async {
    if (role == null || role.isEmpty) {
      await _storage.delete(key: _userRoleKey);
      return;
    }

    await _storage.write(key: _userRoleKey, value: role);
  }

  Future<String?> getUserRole() => _storage.read(key: _userRoleKey);

  Future<void> saveDepartmentName(String? departmentName) async {
    if (departmentName == null || departmentName.isEmpty) {
      await _storage.delete(key: _departmentNameKey);
      return;
    }

    await _storage.write(key: _departmentNameKey, value: departmentName);
  }

  Future<String?> getDepartmentName() => _storage.read(key: _departmentNameKey);

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() => _storage.deleteAll();
}
