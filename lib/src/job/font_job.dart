import '../common/api.dart';
import '../common/stroke_width_range.dart';

/// One icon-font generation job with fully resolved options.
class FontJob {
  FontJob({
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
    this.useOpenType = true,
    this.strokeWidthRange,
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
  final bool useOpenType;

  /// When set, builds a variable font whose `wght` axis is the stroke width,
  /// spanning this range. See [StrokeWidthRange] and `svgToOtf`'s
  /// `strokeWidthRange` parameter, which this is passed straight through to.
  final StrokeWidthRange? strokeWidthRange;
}

/// Result of [runFontJob].
class FontJobResult {
  FontJobResult({this.name, required this.otf, this.classSource});

  final String? name;
  final SvgToOtfResult otf;
  final String? classSource;
}
