import 'dart:async';
import 'dart:io';

import 'package:fontify_plus/src/cli/arguments.dart';
import 'package:fontify_plus/src/cli/debouncer.dart';
import 'package:fontify_plus/src/cli/watch_loop.dart';
import 'package:fontify_plus/src/job/font_job.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('SVG debounce regenerates; config reparses all jobs', () async {
    final icons = FontJob(
      inputSvgDir: 'assets/icons',
      outputFontFile: 'fonts/icons.otf',
    );
    final brand = FontJob(
      inputSvgDir: 'assets/brand',
      outputFontFile: 'fonts/brand.otf',
    );

    final svgCtrl = StreamController<FileSystemEvent>.broadcast();
    final configCtrl = StreamController<FileSystemEvent>.broadcast();
    final runs = <List<String>>[];
    var reparses = 0;

    final initial = CliRunRequest(
      jobs: [icons],
      verbose: false,
      watch: true,
      configFilePath: 'pubspec.yaml',
    );

    final loop = runWatchLoop(
      initial: initial,
      reparse: () {
        reparses++;
        return CliRunRequest(
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
}
