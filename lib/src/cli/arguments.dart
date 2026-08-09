import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

import '../job/font_job.dart';
import '../job/fontify_config.dart';
import '../job/fontify_exception.dart';
import '../job/job_field.dart';
import '../job/job_values.dart';
import '../utils/logger.dart';
import 'cli_exception.dart';
import 'options.dart';

export 'cli_exception.dart';
export 'options.dart';

const _kDefaultConfigPathList = ['pubspec.yaml', 'fontify_plus.yaml'];

/// Parsed CLI invocation: jobs, verbose, optional [watch] and [configFilePath].
class CliRunRequest {
  CliRunRequest({
    required this.jobs,
    required this.verbose,
    this.watch = false,
    this.configFilePath,
  });

  final List<FontJob> jobs;
  final bool verbose;
  final bool watch;
  final String? configFilePath;
}

/// Parses argv and optional config into [CliRunRequest].
CliRunRequest parseArgsAndConfig(ArgParser argParser, List<String> args) {
  late final ArgResults argResults;

  try {
    argResults = argParser.parse(args);
  } on FormatException catch (err) {
    throw CliArgumentException(err.message);
  }

  if (argResults[kCliHelpOption] as bool) {
    throw CliHelpException();
  }

  final cliOverrides = _cliOverridesFrom(argResults);
  final fontFilter = argResults[kCliFontOption] as String?;
  final configFilePath = argResults[kCliConfigFileOption] as String?;

  final positionalCount = math.min(
    kPositionalJobFields.length,
    argResults.rest.length,
  );
  final hasPositionals = positionalCount > 0;

  if (hasPositionals && fontFilter != null) {
    throw CliArgumentException(
      '--$kCliFontOption cannot be used with positional arguments.',
    );
  }

  final configFile = _findConfigFile(configFilePath);
  final configSource = configFile?.readAsStringSync();
  FontifyConfig? config;
  if (configSource != null) {
    try {
      config = tryParseFontifyConfig(configSource);
    } on YamlException catch (e) {
      throw CliArgumentException(e.message);
    } on FontifyException catch (e) {
      throw CliArgumentException(e.message);
    }
  }

  if (hasPositionals) {
    if (config != null) {
      throw CliArgumentException(
        'Use either positional arguments for a one-off run or a config file '
        'with fontify_plus.fonts, not both.',
      );
    }

    if (positionalCount < kPositionalJobFields.length) {
      throw CliArgumentException(
        'Both <input-svg-dir> and <output-font-file> are required.',
      );
    }

    final layers = <JobValues>[
      {
        for (var i = 0; i < positionalCount; i++)
          kPositionalJobFields[i]: argResults.rest[i],
      },
      cliOverrides,
    ];

    try {
      return CliRunRequest(
        jobs: [resolveFontJob(layers: layers)],
        verbose: resolveVerboseFromLayers(layers),
        watch: argResults[kCliWatchOption] as bool,
        configFilePath: null,
      );
    } on FontifyException catch (e) {
      throw CliArgumentException(e.message);
    }
  }

  if (config == null) {
    throw CliArgumentException(
      'No config found. Provide <input-svg-dir> and <output-font-file>, or '
      'add a fontify_plus.fonts section to pubspec.yaml or fontify_plus.yaml.',
    );
  }

  logger.i('Using config ${configFile!.path}');

  try {
    return CliRunRequest(
      jobs: config.resolve(
        cliOverrides: cliOverrides,
        fontFilter: fontFilter,
      ),
      verbose: config.resolveVerbose(cliOverrides: cliOverrides),
      watch: argResults[kCliWatchOption] as bool,
      configFilePath: configFile.path,
    );
  } on FontifyException catch (e) {
    throw CliArgumentException(e.message);
  }
}

JobValues _cliOverridesFrom(ArgResults argResults) {
  final overrides = <JobField, Object?>{};

  for (final field in kJobCliOptions.entries) {
    final option = field.value;
    if (!argResults.wasParsed(option)) {
      continue;
    }
    overrides[field.key] = argResults[option];
  }

  return overrides;
}

File? _findConfigFile(String? explicitPath) {
  final paths = <String>[
    ?explicitPath,
    ..._kDefaultConfigPathList,
  ];

  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) {
      continue;
    }

    try {
      final source = file.readAsStringSync();
      if (tryParseFontifyConfig(source) != null) {
        return file;
      }
    } on YamlException {
      continue;
    }
  }

  return null;
}
