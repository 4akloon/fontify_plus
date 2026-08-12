import 'dart:io';

import 'package:args/args.dart';
import 'package:fontify_plus/src/cli/arguments.dart';
import 'package:fontify_plus/src/cli/watch_loop.dart';
import 'package:fontify_plus/src/job/run_font_job.dart';
import 'package:fontify_plus/src/utils/logger.dart';
import 'package:yaml/yaml.dart';

final _argParser = ArgParser(allowTrailingOptions: true);

Future<void> main(List<String> args) async {
  defineOptions(_argParser);

  late final CliRunRequest request;

  try {
    request = parseArgsAndConfig(_argParser, args);
  } on CliArgumentException catch (e) {
    _usageError(e.message);
  } on CliHelpException {
    _printHelp();
  } on YamlException catch (e) {
    logger.e(e.toString());
    exit(66);
  }

  try {
    await _run(request, () => parseArgsAndConfig(_argParser, args));
  } on Object catch (e) {
    logger.e(e.toString());
    exit(65);
  }
}

Future<void> _run(
  CliRunRequest request,
  CliRunRequest Function() reparse,
) async {
  if (request.verbose) {
    logger.level = Level.trace;
  }

  final stopwatch = Stopwatch()..start();
  runFontJobs(request.jobs);
  logger.i(
    'Finished ${request.jobs.length} job(s) in ${stopwatch.elapsedMilliseconds}ms',
  );

  if (!request.watch) {
    return;
  }

  await runWatchLoop(
    initial: request,
    reparse: reparse,
    runJobs: runFontJobs,
  );
}

void _printHelp() {
  _printUsage();
  exit(exitCode);
}

void _usageError(String error) {
  _printUsage(error);
  exit(64);
}

void _printUsage([String? error]) {
  final message = error ?? _kAbout;

  stdout.write('''
$message

$_kUsage
${_argParser.usage}
''');
}

const _kAbout =
    'Converts .svg icons to an OpenType font and generates Flutter-compatible class.';

const _kUsage = '''
Usage:   fontify_plus [<input-svg-dir> <output-font-file>] [options]

Examples:
  fontify_plus assets/svg/ fonts/my_icons_font.otf --output-class-file=lib/my_icons.dart
  fontify_plus --font=icons

Converts every .svg file from <input-svg-dir> to an OpenType font, or runs named
font sets from a fontify_plus.fonts config in pubspec.yaml / fontify_plus.yaml.
''';
