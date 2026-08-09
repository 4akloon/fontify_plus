import 'dart:async';

import 'package:fontify_plus/src/cli/debouncer.dart';
import 'package:test/test.dart';

class _FakeTimer implements Timer {
  _FakeTimer(this._callback);

  final void Function() _callback;
  var _canceled = false;

  @override
  bool get isActive => !_canceled;

  void complete() {
    if (!_canceled) _callback();
  }

  @override
  void cancel() => _canceled = true;

  @override
  int get tick => 0;
}

void main() {
  test('debouncer keeps only the last action', () {
    final timers = <_FakeTimer>[];

    final d = Debouncer(
      delay: const Duration(milliseconds: 250),
      createTimer: (duration, callback) {
        expect(duration, const Duration(milliseconds: 250));
        final timer = _FakeTimer(callback);
        timers.add(timer);
        return timer;
      },
    );

    var firstRuns = 0;
    var secondRuns = 0;
    d(() => firstRuns++);
    d(() => secondRuns++);

    expect(timers.length, 2);
    expect(timers[0].isActive, isFalse);

    timers[1].complete();
    expect(firstRuns, 0);
    expect(secondRuns, 1);
  });

  test('cancel prevents pending action', () {
    final timers = <_FakeTimer>[];

    final d = Debouncer(
      createTimer: (duration, callback) {
        final timer = _FakeTimer(callback);
        timers.add(timer);
        return timer;
      },
    );

    var runs = 0;
    d(() => runs++);
    d.cancel();

    expect(timers.single.isActive, isFalse);
    timers.single.complete();
    expect(runs, 0);
  });

  test('default delay is 250ms', () {
    Duration? captured;

    final d = Debouncer(
      createTimer: (duration, callback) {
        captured = duration;
        return _FakeTimer(callback);
      },
    );

    d(() {});
    expect(captured, const Duration(milliseconds: 250));
  });
}
