import 'dart:async';

final _controller = StreamController<void>.broadcast();

/// Emits an event when the API returns 401 — consumed by [AuthController].
Stream<void> get forceLogoutStream => _controller.stream;

void triggerForceLogout() {
  if (!_controller.isClosed) _controller.add(null);
}
