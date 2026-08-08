import 'dart:io';

import 'cli_argument.dart';

/// Contains all the parsed data for the application.
class CliArguments {
  CliArguments(
    this.svgDir,
    this.fontFile,
    this.classFile,
    this.className,
    this.indent,
    this.fontPackage,
    this.fontName,
    this.recursive,
    this.outlineStrokes,
    this.normalize,
    this.useOpenType,
    this.verbose,
    this.configFile,
  );

  /// Creates [CliArguments] for a map of raw values.
  ///
  /// The map must already have been validated and formatted; the casts here
  /// are what that step guarantees.
  factory CliArguments.fromMap(Map<CliArgument, dynamic> map) => CliArguments(
    map[CliArgument.svgDir] as Directory,
    map[CliArgument.fontFile] as File,
    map[CliArgument.classFile] as File?,
    map[CliArgument.className] as String?,
    map[CliArgument.indent] as int?,
    map[CliArgument.fontPackage] as String?,
    map[CliArgument.fontName] as String?,
    map[CliArgument.recursive] as bool?,
    map[CliArgument.outlineStrokes] as bool?,
    map[CliArgument.normalize] as bool?,
    map[CliArgument.useOpenType] as bool?,
    map[CliArgument.verbose] as bool?,
    map[CliArgument.configFile] as File?,
  );

  final Directory svgDir;
  final File fontFile;
  final File? classFile;
  final String? className;
  final String? fontPackage;
  final int? indent;
  final String? fontName;
  final bool? recursive;

  /// Whether stroked paths are converted into the filled region they cover.
  final bool? outlineStrokes;
  final bool? normalize;

  /// Whether outlines are stored as CFF (cubic) rather than TrueType
  /// (quadratic).
  final bool? useOpenType;
  final bool? verbose;
  final File? configFile;
}

// Ignoring as CLI arguments are dynamically typed
// ignore_for_file: avoid_annotating_with_dynamic
