/// Base exception for all server-side errors.
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Thrown when the server returns 401 Unauthorized.
class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'غير مصرح بالوصول، يرجى تسجيل الدخول']);
  @override
  String toString() => message;
}

/// Thrown when the server returns 422 Unprocessable Entity (Laravel validation).
class ValidationException implements Exception {
  final String message;
  final Map<String, List<String>>? errors;
  const ValidationException(this.message, {this.errors});

  /// Returns the first field error, or falls back to the general message.
  String get displayMessage =>
      errors?.values.firstOrNull?.firstOrNull ?? message;

  @override
  String toString() => displayMessage;
}

/// Thrown when the device cannot reach the server (no connectivity / timeout).
class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'تعذّر الاتصال بالخادم، تحقق من الإنترنت']);
  @override
  String toString() => message;
}
