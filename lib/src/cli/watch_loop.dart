import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../job/font_job.dart';
import '../utils/logger.dart';
import 'arguments.dart';
import 'debouncer.dart';
import 'watch_match.dart';

Future<void> runWatchLoop({
  required CliRunRequest initial,
  required CliRunRequest Function() reparse,
  required void Function(List<FontJob> jobs) runJobs,
  Stream<FileSystemEvent> Function(String path, {bool recursive})?
      watchDirectory,
  Debouncer? debouncer,
}) async {
  final watch =
      watchDirectory ??
      ((String path, {bool recursive = false}) =>
          Directory(path).watch(recursive: recursive));
  final debounce = debouncer ?? Debouncer();

  var current = initial;
  var busy = false;
  var pendingSvg = false;
  var pendingConfig = false;
  String? pendingSvgPath;
  var generation = 0;
  final subs = <StreamSubscription<FileSystemEvent>>[];
  final shutdown = Completer<void>();
  var activeStreams = 0;

  void runSafe(List<FontJob> jobs) {
    try {
      runJobs(jobs);
    } on Object catch (e) {
      logger.e(e.toString());
    }
  }

  late void Function() rebuild;
  late void Function() handleConfig;
  late void Function(String path) runSvg;

  void drainPending() {
    if (pendingConfig) {
      pendingConfig = false;
      pendingSvg = false;
      pendingSvgPath = null;
      handleConfig();
      return;
    }
    if (pendingSvg) {
      pendingSvg = false;
      final path = pendingSvgPath;
      pendingSvgPath = null;
      if (path != null) {
        runSvg(path);
      }
    }
  }

  void startRun(List<FontJob> jobs) {
    busy = true;
    runSafe(jobs);
    busy = false;
    drainPending();
  }

  runSvg = (String path) {
    final jobs = jobsForSvgPath(current.jobs, path);
    if (jobs.isEmpty) {
      return;
    }
    if (busy) {
      pendingSvg = true;
      pendingSvgPath = path;
      return;
    }
    startRun(jobs);
  };

  handleConfig = () {
    debounce.cancel();
    pendingSvg = false;
    pendingSvgPath = null;

    if (busy) {
      pendingConfig = true;
      return;
    }

    late final CliRunRequest next;
    try {
      next = reparse();
    } on Object catch (e) {
      logger.e(e.toString());
      return;
    }

    current = next;
    startRun(current.jobs);
    rebuild();
  };

  void onEvent(FileSystemEvent event) {
    final configPath = current.configFilePath;
    if (configPath != null && isConfigPath(event.path, configPath)) {
      handleConfig();
      return;
    }
    if (!isSvgPath(event.path)) {
      return;
    }
    final path = event.path;
    debounce(() => runSvg(path));
  }

  rebuild = () {
    final gen = ++generation;
    for (final sub in subs) {
      unawaited(sub.cancel());
    }
    subs.clear();

    final dirRecursive = <String, bool>{};
    for (final job in current.jobs) {
      dirRecursive.update(
        job.inputSvgDir,
        (existing) => existing || job.recursive,
        ifAbsent: () => job.recursive,
      );
    }

    final targets = <({String path, bool recursive})>[
      for (final e in dirRecursive.entries)
        (path: e.key, recursive: e.value),
    ];

    final configPath = current.configFilePath;
    if (configPath != null) {
      final configDir = p.dirname(configPath);
      if (!dirRecursive.containsKey(configDir)) {
        targets.add((path: configDir, recursive: false));
      }
    }

    final dirs = dirRecursive.keys.toList()..sort();
    final configPart =
        configPath == null ? '' : ' and config $configPath';
    logger.i('Watching ${dirs.join(', ')}$configPart');

    activeStreams = targets.length;
    if (activeStreams == 0) {
      if (!shutdown.isCompleted) {
        shutdown.complete();
      }
      return;
    }

    for (final target in targets) {
      final stream = watch(target.path, recursive: target.recursive);
      final sub = stream.listen(
        (event) {
          if (gen != generation) {
            return;
          }
          onEvent(event);
        },
        onDone: () {
          if (gen != generation) {
            return;
          }
          activeStreams--;
          if (activeStreams == 0 && !shutdown.isCompleted) {
            shutdown.complete();
          }
        },
        onError: (Object e) {
          if (gen != generation) {
            return;
          }
          logger.e(e.toString());
        },
        cancelOnError: false,
      );
      subs.add(sub);
    }
  };

  rebuild();
  await shutdown.future;
}
