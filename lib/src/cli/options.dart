import 'package:args/args.dart';

import '../job/job_field.dart';

const kCliFontOption = 'font';
const kCliConfigFileOption = 'config-file';
const kCliHelpOption = 'help';
const kCliWatchOption = 'watch';

const kPositionalJobFields = [JobField.inputSvgDir, JobField.outputFontFile];

void defineOptions(ArgParser argParser) {
  argParser
    ..addSeparator('Flutter class options:')
    ..addOption(
      kJobCliOptions[JobField.outputClassFile]!,
      abbr: 'o',
      help:
          'Output path for Flutter-compatible class that contains identifiers for the icons.',
      valueHelp: 'path',
    )
    ..addOption(
      kJobCliOptions[JobField.indent]!,
      abbr: 'i',
      help: 'Number of spaces in leading indentation for Flutter class file.',
      valueHelp: 'indent',
    )
    ..addOption(
      kJobCliOptions[JobField.className]!,
      abbr: 'c',
      help: 'Name for a generated class.',
      valueHelp: 'name',
    )
    ..addOption(
      kJobCliOptions[JobField.package]!,
      abbr: 'p',
      help:
          'Name of a package that provides a font. Used to provide a font through package dependency.',
      valueHelp: 'name',
    )
    ..addSeparator('Font options:')
    ..addOption(
      kJobCliOptions[JobField.fontName]!,
      abbr: 'f',
      help: 'Name for a generated font.',
      valueHelp: 'name',
    )
    ..addFlag(
      kJobCliOptions[JobField.normalize]!,
      help:
          'Scales each glyph so its own longest side fills the em square '
          '(default on). Disable with --no-normalize to map each viewBox '
          'onto the em square and keep relative artboard sizes.',
    )
    ..addFlag(
      kJobCliOptions[JobField.outlineStrokes]!,
      help:
          'Converts stroked paths into the filled region the stroke covers. '
          'Font glyphs are fill-only, so outline-style icons need this.',
    )
    ..addFlag(
      kJobCliOptions[JobField.preview]!,
      help: 'Embed SVG previews in generated IconData dartdoc.',
    )
    ..addFlag(
      kJobCliOptions[JobField.useOpenType]!,
      help:
          'Stores outlines as CFF rather than TrueType. CFF holds the cubic '
          'curves an SVG is drawn with directly; TrueType has to approximate '
          'them with quadratics, which costs points.',
    )
    ..addSeparator('Other options:')
    ..addOption(
      kCliConfigFileOption,
      abbr: 'z',
      help:
          'Path to fontify_plus yaml configuration file. pubspec.yaml and fontify_plus.yaml files are used by default.',
      valueHelp: 'path',
    )
    ..addOption(
      kCliFontOption,
      help:
          'Run a single named font set from the config file. Omit to run all sets.',
      valueHelp: 'name',
    )
    ..addFlag(
      kJobCliOptions[JobField.recursive]!,
      abbr: 'r',
      help: 'Recursively look for .svg files.',
    )
    ..addFlag(
      kJobCliOptions[JobField.verbose]!,
      abbr: 'v',
      help: 'Display every logging message.',
    )
    ..addFlag(
      kCliWatchOption,
      help:
          'Watch SVG inputs (and config file, if any) and regenerate on change.',
      negatable: false,
    )
    ..addFlag(
      kCliHelpOption,
      abbr: 'h',
      help: 'Shows this usage information.',
      negatable: false,
    );
}
