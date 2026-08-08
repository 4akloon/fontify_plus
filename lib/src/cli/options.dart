import 'package:args/args.dart';

import 'cli_argument.dart';

void defineOptions(ArgParser argParser) {
  argParser
    ..addSeparator('Flutter class options:')
    ..addOption(
      kOptionNames[CliArgument.classFile]!,
      abbr: 'o',
      help:
          'Output path for Flutter-compatible class that contains identifiers for the icons.',
      valueHelp: 'path',
    )
    ..addOption(
      kOptionNames[CliArgument.indent]!,
      abbr: 'i',
      help: 'Number of spaces in leading indentation for Flutter class file.',
      valueHelp: 'indent',
      defaultsTo: '2',
    )
    ..addOption(
      kOptionNames[CliArgument.className]!,
      abbr: 'c',
      help: 'Name for a generated class.',
      valueHelp: 'name',
    )
    ..addOption(
      kOptionNames[CliArgument.fontPackage]!,
      abbr: 'p',
      help:
          'Name of a package that provides a font. Used to provide a font through package dependency.',
      valueHelp: 'name',
    )
    ..addSeparator('Font options:')
    ..addOption(
      kOptionNames[CliArgument.fontName]!,
      abbr: 'f',
      help: 'Name for a generated font.',
      valueHelp: 'name',
    )
    ..addFlag(
      kOptionNames[CliArgument.normalize]!,
      help: 'Scales each glyph so its own longest side fills the em square. '
          'Only for icons from mismatched sources: it discards how much of '
          'its artboard each icon was drawn to occupy, so a full-bleed icon '
          'and a small one come out the same size.',
      defaultsTo: false,
    )
    ..addFlag(
      kOptionNames[CliArgument.ignoreShapes]!,
      help: 'Discards SVG shape elements (circle, rect, etc.) instead of '
          'converting them to paths. Enabling this silently drops geometry.',
      defaultsTo: false,
    )
    ..addFlag(
      kOptionNames[CliArgument.outlineStrokes]!,
      help: 'Converts stroked paths into the filled region the stroke covers. '
          'Font glyphs are fill-only, so outline-style icons need this.',
      defaultsTo: true,
    )
    ..addFlag(
      kOptionNames[CliArgument.useOpenType]!,
      help: 'Stores outlines as CFF rather than TrueType. CFF holds the cubic '
          'curves an SVG is drawn with directly; TrueType has to approximate '
          'them with quadratics, which costs points.',
      defaultsTo: true,
    )
    ..addSeparator('Other options:')
    ..addOption(
      kOptionNames[CliArgument.configFile]!,
      abbr: 'z',
      help:
          'Path to fontify_plus yaml configuration file. pubspec.yaml and fontify_plus.yaml files are used by default.',
      valueHelp: 'path',
    )
    ..addFlag(
      kOptionNames[CliArgument.recursive]!,
      abbr: 'r',
      help: 'Recursively look for .svg files.',
      defaultsTo: kDefaultRecursive,
      negatable: false,
    )
    ..addFlag(
      kOptionNames[CliArgument.verbose]!,
      abbr: 'v',
      help: 'Display every logging message.',
      defaultsTo: kDefaultVerbose,
      negatable: false,
    )
    ..addFlag(
      kOptionNames[CliArgument.help]!,
      abbr: 'h',
      help: 'Shows this usage information.',
      negatable: false,
    );
}
