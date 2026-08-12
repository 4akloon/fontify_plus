import 'dart:async';
import 'dart:io';

import 'package:fontify_plus/src/cli/arguments.dart';
import 'package:fontify_plus/src/cli/debouncer.dart';
import 'package:fontify_plus/src/cli/watch_loop.dart';
import 'package:fontify_plus/src/job/font_job.dart';
import 'package:path/path.dart' as p;
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

Debouncer _manualDebouncer(List<_FakeTimer> timers) {
  return Debouncer(
    createTimer: (duration, callback) {
      final timer = _FakeTimer(callback);
      timers.add(timer);
      return timer;
    },
  );
}

void main() {
  test('SVG debounce regenerates; config reparses all jobs', () async {
    const icons = FontJob(
      inputSvgDir: 'assets/icons',
      outputFontFile: 'fonts/icons.otf',
    );
    const brand = FontJob(
      inputSvgDir: 'assets/brand',
      outputFontFile: 'fonts/brand.otf',
    );

    final svgCtrl = StreamController<FileSystemEvent>.broadcast();
    final configCtrl = StreamController<FileSystemEvent>.broadcast();
    final runs = <List<String>>[];
    var reparses = 0;

    const initial = CliRunRequest(
      jobs: [icons],
      verbose: false,
      watch: true,
      configFilePath: 'pubspec.yaml',
    );

    final loop = runWatchLoop(
      initial: initial,
      reparse: () {
        reparses++;
        return const CliRunRequest(
          jobs: [icons, brand],
          verbose: false,
          watch: true,
          configFilePath: 'pubspec.yaml',
        );
      },
      runJobs: (jobs) => runs.add(jobs.map((j) => j.inputSvgDir).toList()),
      watchDirectory: (path, {recursive = false}) {
        if (path == 'assets/icons' || path == 'assets/brand') {
          return svgCtrl.stream;
        }
        if (path == p.dirname('pubspec.yaml')) {
          return configCtrl.stream;
        }
        return const Stream.empty();
      },
      debouncer: Debouncer(delay: Duration.zero),
    );

    svgCtrl.add(FileSystemModifyEvent('assets/icons/a.svg', false, false));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(runs, [
      ['assets/icons'],
    ]);

    configCtrl.add(FileSystemModifyEvent('pubspec.yaml', false, false));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(reparses, 1);
    expect(runs, [
      ['assets/icons'],
      ['assets/icons', 'assets/brand'],
    ]);

    await svgCtrl.close();
    await configCtrl.close();
    await loop;
  });

  test('multi-path SVG coalesce unions jobs in one run', () async {
    const icons = FontJob(
      inputSvgDir: 'assets/icons',
      outputFontFile: 'fonts/icons.otf',
    );
    const brand = FontJob(
      inputSvgDir: 'assets/brand',
      outputFontFile: 'fonts/brand.otf',
    );

    final svgCtrl = StreamController<FileSystemEvent>.broadcast();
    final timers = <_FakeTimer>[];
    final runs = <List<String>>[];

    final loop = runWatchLoop(
      initial: const CliRunRequest(
        jobs: [icons, brand],
        verbose: false,
        watch: true,
      ),
      reparse: () => throw StateError('unexpected reparse'),
      runJobs: (jobs) => runs.add(jobs.map((j) => j.inputSvgDir).toList()),
      watchDirectory: (path, {recursive = false}) {
        if (path == 'assets/icons' || path == 'assets/brand') {
          return svgCtrl.stream;
        }
        return const Stream.empty();
      },
      debouncer: _manualDebouncer(timers),
    );

    await Future<void>.delayed(Duration.zero);

    svgCtrl.add(FileSystemModifyEvent('assets/icons/a.svg', false, false));
    svgCtrl.add(FileSystemModifyEvent('assets/brand/b.svg', false, false));
    await Future<void>.delayed(Duration.zero);

    expect(timers, isNotEmpty);
    expect(runs, isEmpty);
    timers.last.complete();
    expect(runs, [
      ['assets/icons', 'assets/brand'],
    ]);

    await svgCtrl.close();
    await loop;
  });

  test('config cancels pending SVG debounce', () async {
    const icons = FontJob(
      inputSvgDir: 'assets/icons',
      outputFontFile: 'fonts/icons.otf',
    );
    const brand = FontJob(
      inputSvgDir: 'assets/brand',
      outputFontFile: 'fonts/brand.otf',
    );

    final svgCtrl = StreamController<FileSystemEvent>.broadcast();
    final configCtrl = StreamController<FileSystemEvent>.broadcast();
    final timers = <_FakeTimer>[];
    final runs = <List<String>>[];
    var reparses = 0;

    final loop = runWatchLoop(
      initial: const CliRunRequest(
        jobs: [icons],
        verbose: false,
        watch: true,
        configFilePath: 'pubspec.yaml',
      ),
      reparse: () {
        reparses++;
        return const CliRunRequest(
          jobs: [icons, brand],
          verbose: false,
          watch: true,
          configFilePath: 'pubspec.yaml',
        );
      },
      runJobs: (jobs) => runs.add(jobs.map((j) => j.inputSvgDir).toList()),
      watchDirectory: (path, {recursive = false}) {
        if (path == 'assets/icons' || path == 'assets/brand') {
          return svgCtrl.stream;
        }
        if (path == p.dirname('pubspec.yaml')) {
          return configCtrl.stream;
        }
        return const Stream.empty();
      },
      debouncer: _manualDebouncer(timers),
    );

    await Future<void>.delayed(Duration.zero);

    svgCtrl.add(FileSystemModifyEvent('assets/icons/a.svg', false, false));
    await Future<void>.delayed(Duration.zero);
    expect(timers, isNotEmpty);
    final svgTimer = timers.last;

    configCtrl.add(FileSystemModifyEvent('pubspec.yaml', false, false));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(reparses, 1);
    expect(runs, [
      ['assets/icons', 'assets/brand'],
    ]);
    expect(svgTimer.isActive, isFalse);
    svgTimer.complete();
    expect(runs, [
      ['assets/icons', 'assets/brand'],
    ]);

    await svgCtrl.close();
    await configCtrl.close();
    await loop;
  });

  test('throwing runJobs is swallowed; later events still run', () async {
    const icons = FontJob(
      inputSvgDir: 'assets/icons',
      outputFontFile: 'fonts/icons.otf',
    );

    final svgCtrl = StreamController<FileSystemEvent>.broadcast();
    final timers = <_FakeTimer>[];
    final runs = <List<String>>[];
    var calls = 0;

    final loop = runWatchLoop(
      initial: const CliRunRequest(
        jobs: [icons],
        verbose: false,
        watch: true,
      ),
      reparse: () => throw StateError('unexpected reparse'),
      runJobs: (jobs) {
        calls++;
        if (calls == 1) {
          throw StateError('boom');
        }
        runs.add(jobs.map((j) => j.inputSvgDir).toList());
      },
      watchDirectory: (path, {recursive = false}) {
        if (path == 'assets/icons') {
          return svgCtrl.stream;
        }
        return const Stream.empty();
      },
      debouncer: _manualDebouncer(timers),
    );

    await Future<void>.delayed(Duration.zero);

    svgCtrl.add(FileSystemModifyEvent('assets/icons/a.svg', false, false));
    await Future<void>.delayed(Duration.zero);
    timers.last.complete();
    expect(calls, 1);
    expect(runs, isEmpty);

    svgCtrl.add(FileSystemModifyEvent('assets/icons/b.svg', false, false));
    await Future<void>.delayed(Duration.zero);
    timers.last.complete();
    expect(calls, 2);
    expect(runs, [
      ['assets/icons'],
    ]);

    await svgCtrl.close();
    await loop;
  });
}
