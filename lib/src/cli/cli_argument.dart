import '../utils/enum_class.dart';

const kDefaultVerbose = false;
const kDefaultRecursive = false;

enum CliArgument {
  // Required
  svgDir,
  fontFile,

  // Class-related
  classFile,
  className,
  indent,
  fontPackage,

  // Font-related
  fontName,
  ignoreShapes,
  outlineStrokes,
  normalize,

  // Others
  recursive,
  verbose,

  // Only in CLI
  help,
  configFile,
}

/// Types each argument accepts, whether it arrives from the command line or
/// from a config file.
const kArgAllowedTypes = <CliArgument, List<Type>>{
  CliArgument.svgDir: [String],
  CliArgument.fontFile: [String],
  CliArgument.classFile: [String],
  CliArgument.className: [String],
  CliArgument.fontPackage: [String],
  CliArgument.indent: [String, int],
  CliArgument.fontName: [String],
  CliArgument.normalize: [bool],
  CliArgument.ignoreShapes: [bool],
  CliArgument.outlineStrokes: [bool],
  CliArgument.recursive: [bool],
  CliArgument.verbose: [bool],
  CliArgument.help: [bool],
  CliArgument.configFile: [String],
};

/// Command-line option name for each argument.
const kOptionNames = EnumClass<CliArgument, String>({
  // svgDir and fontFile are not options

  CliArgument.classFile: 'output-class-file',
  CliArgument.className: 'class-name',
  CliArgument.indent: 'indent',
  CliArgument.fontPackage: 'package',

  CliArgument.fontName: 'font-name',
  CliArgument.normalize: 'normalize',
  CliArgument.ignoreShapes: 'ignore-shapes',
  CliArgument.outlineStrokes: 'outline-strokes',

  CliArgument.recursive: 'recursive',
  CliArgument.verbose: 'verbose',

  CliArgument.help: 'help',
  CliArgument.configFile: 'config-file',
});

/// Config file key for each argument.
const kConfigKeys = EnumClass<CliArgument, String>({
  CliArgument.svgDir: 'input_svg_dir',
  CliArgument.fontFile: 'output_font_file',

  CliArgument.classFile: 'output_class_file',
  CliArgument.className: 'class_name',
  CliArgument.indent: 'indent',
  CliArgument.fontPackage: 'package',

  CliArgument.fontName: 'font_name',
  CliArgument.normalize: 'normalize',
  CliArgument.ignoreShapes: 'ignore_shapes',
  CliArgument.outlineStrokes: 'outline_strokes',

  CliArgument.recursive: 'recursive',
  CliArgument.verbose: 'verbose',

  // help and configFile are not part of config
});

/// Whichever name an argument goes by, for use in error messages.
final Map<CliArgument, String> argumentNames = {
  ...kConfigKeys.map,
  ...kOptionNames.map,
};
