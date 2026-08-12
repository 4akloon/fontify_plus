import 'dart:async';

class Debouncer {
  Debouncer({
    this.delay = const Duration(milliseconds: 250),
    Timer Function(Duration duration, void Function() callback)? createTimer,
  }) : _createTimer = createTimer ?? Timer.new;

  final Duration delay;
  final Timer Function(Duration, void Function()) _createTimer;
  Timer? _timer;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = _createTimer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
