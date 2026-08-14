import '../common/api.dart';
import '../common/stroke_width_range.dart';

/// One icon-font generation job with fully resolved options.
class FontJob {
  const FontJob({
    this.name,
    required this.inputSvgDir,
    required this.outputFontFile,
    this.outputClassFile,
    this.className,
    this.fontName,
    this.package,
    this.indent = 2,
    this.recursive = false,
    this.normalize = true,
    this.outlineStrokes = true,
    this.preview,
    this.useOpenType = true,
    this.strokeWidthRange,
    this.defaultStrokeWidth,
  });

  final String? name;
  final String inputSvgDir;
  final String outputFontFile;
  final String? outputClassFile;
  final String? className;
  final String? fontName;
  final String? package;
  final int indent;
  final bool recursive;
  final bool normalize;
  final bool outlineStrokes;
  final bool? preview;
  final bool useOpenType;

  /// When set, builds a variable font whose `wght` axis is the stroke width,
  /// spanning this range. See [StrokeWidthRange] and `svgToOtf`'s
  /// `strokeWidthRange` parameter, which this is passed straight through to.
  final StrokeWidthRange? strokeWidthRange;

  /// When set, the width the variable font opens at, instead of
  /// [StrokeWidthRange.max]. Requires [strokeWidthRange] and must lie
  /// strictly inside it; both conditions are checked while the job is
  /// resolved, so that a bad pairing is reported against the config keys the
  /// user wrote rather than against `svgToOtf`'s parameter names. Passed
  /// straight through to `svgToOtf`'s `defaultStrokeWidth` parameter.
  final double? defaultStrokeWidth;
}

/// Result of [runFontJob].
class FontJobResult {
  const FontJobResult({this.name, required this.otf, this.classSource});

  final String? name;
  final SvgToOtfResult otf;
  final String? classSource;
}
