import 'dart:async';

/// Throttle с финальным вызовом: первый [trigger] после простоя вызывает
/// [onFire] немедленно и открывает окно [window]. Повторные [trigger] в
/// течение окна не вызывают [onFire] сразу (не чаще одного раза в
/// [window]), а откладывают один финальный вызов на границу окна —
/// изменение не теряется, даже если пришло только одно повторное событие.
class TrailingThrottle {
  final void Function() onFire;
  final Duration window;

  Timer? _cooldownTimer;
  bool _pendingDuringCooldown = false;
  bool _disposed = false;

  TrailingThrottle({required this.onFire, required this.window});

  void trigger() {
    if (_disposed) return;
    if (_cooldownTimer == null) {
      onFire();
      _startCooldown();
    } else {
      _pendingDuringCooldown = true;
    }
  }

  void _startCooldown() {
    _cooldownTimer = Timer(window, () {
      _cooldownTimer = null;
      if (_disposed) return;
      if (_pendingDuringCooldown) {
        _pendingDuringCooldown = false;
        onFire();
        _startCooldown();
      }
    });
  }

  void dispose() {
    _disposed = true;
    _cooldownTimer?.cancel();
  }
}
