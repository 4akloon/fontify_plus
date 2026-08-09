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
  final pendingSvgPaths = <String>{};
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

  void flushSvg() {
    final paths = pendingSvgPaths.toList();
    pendingSvgPaths.clear();
    final seen = <FontJob>{};
    final jobs = <FontJob>[];
    for (final path in paths) {
      for (final job in jobsForSvgPath(current.jobs, path)) {
        if (seen.add(job)) {
          jobs.add(job);
        }
      }
    }
    if (jobs.isEmpty) {
      return;
    }
    runSafe(jobs);
  }

  handleConfig = () {
    debounce.cancel();
    pendingSvgPaths.clear();

    late final CliRunRequest next;
    try {
      next = reparse();
    } on Object catch (e) {
      logger.e(e.toString());
      return;
    }

    current = next;
    runSafe(current.jobs);
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
    pendingSvgPaths.add(event.path);
    debounce(flushSvg);
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
    if (dirs.isEmpty) {
      logger.i(
        configPath == null ? 'Watching' : 'Watching config $configPath',
      );
    } else {
      final configPart =
          configPath == null ? '' : ' and config $configPath';
      logger.i('Watching ${dirs.join(', ')}$configPart');
    }

    activeStreams = 0;
    if (targets.isEmpty) {
      if (!shutdown.isCompleted) {
        shutdown.complete();
      }
      return;
    }

    for (final target in targets) {
      try {
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
        activeStreams++;
      } on Object catch (e) {
        // Re-entrant rebuild from handleConfig must not kill the process.
        logger.e(e.toString());
      }
    }

    if (activeStreams == 0 && !shutdown.isCompleted) {
      shutdown.complete();
    }
  };

  rebuild();
  await shutdown.future;
}
