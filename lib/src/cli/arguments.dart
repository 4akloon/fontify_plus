import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';

import '../utils/logger.dart';
import 'argument_validation.dart';
import 'cli_argument.dart';
import 'cli_arguments.dart';
import 'cli_exception.dart';
import 'config_parser.dart';

export 'argument_validation.dart';
export 'cli_argument.dart';
export 'cli_arguments.dart';
export 'cli_exception.dart';
export 'config_parser.dart';

const _kDefaultConfigPathList = ['pubspec.yaml', 'fontify_plus.yaml'];
const _kPositionalArguments = [CliArgument.svgDir, CliArgument.fontFile];

/// Parses argument list.
///
/// Throws [CliHelpException], if 'help' option is present.
///
/// Returns the raw, unvalidated argument values.
Map<CliArgument, dynamic> parseArguments(
  ArgParser argParser,
  List<String> args,
) {
  late final ArgResults argResults;

  try {
    argResults = argParser.parse(args);
  } on FormatException catch (err) {
    throw CliArgumentException(err.message);
  }

  if (argResults['help'] as bool) {
    throw CliHelpException();
  }

  final posArgsLength =
      math.min(_kPositionalArguments.length, argResults.rest.length);

  return <CliArgument, dynamic>{
    for (final e in kOptionNames.entries) e.key: argResults[e.value],
    for (var i = 0; i < posArgsLength; i++)
      _kPositionalArguments[i]: argResults.rest[i],
  };
}

/// Parses argument list and config file, validates parsed data.
/// Config is used, if it contains 'fontify_plus' section.
///
/// Throws [CliHelpException], if 'help' option is present.
/// Throws [CliArgumentException], if there is an error in arg parsing.
CliArguments parseArgsAndConfig(ArgParser argParser, List<String> args) {
  var parsedArgs = parseArguments(argParser, args);
  final dynamic configFile = parsedArgs[CliArgument.configFile];

  final configList = <String>[
    if (configFile is String) configFile,
    ..._kDefaultConfigPathList,
  ].map(File.new);

  for (final configFile in configList) {
    if (!configFile.existsSync()) {
      continue;
    }

    final parsedConfig = parseConfig(configFile.readAsStringSync());

    if (parsedConfig != null) {
      logger.i('Using config ${configFile.path}');
      parsedArgs = parsedConfig;
      break;
    }
  }

  return CliArguments.fromMap(parsedArgs.validateAndFormat());
}

// Ignoring as CLI arguments are dynamically typed
// ignore_for_file: avoid_annotating_with_dynamic
