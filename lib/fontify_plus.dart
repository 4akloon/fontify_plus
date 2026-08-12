/// Converts SVG icons into an OpenType font and generates a Flutter-compatible
/// class of [IconData] identifiers for them.
///
/// Start with [runFontJob] for directory-based generation, or [svgToOtf] to
/// build the font from an in-memory SVG map, [writeToFile] to write it, and
/// [generateFlutterClass] to emit the Dart class:
///
/// ```dart
/// final result = svgToOtf(
///   svgMap: {'arrow_up': await File('arrow_up.svg').readAsString()},
///   fontName: 'My Icons',
/// );
///
/// writeToFile('MyIcons.otf', result.font);
///
/// final source = generateFlutterClass(
///   glyphList: result.glyphList,
///   familyName: result.font.familyName,
///   className: 'MyIcons',
///   fontFileName: 'MyIcons.otf',
/// );
/// ```
///
/// ## Stroked icons
///
/// A font glyph is a filled region — caps and joins are not stored in the
/// file, only enclosed area. Outline-style icon sets exported from Figma
/// describe the *centreline* of a stroke, which encloses no area and would
/// render blank.
///
/// [svgToOtf] therefore converts stroked paths into the region the stroke
/// covers before encoding them. This is on by default; pass
/// `outlineStrokes: false` to treat path data as fill geometry instead.
///
/// ## Variable stroke width
///
/// Pass [StrokeWidthRange] to [svgToOtf] (or `stroke_width_range` in YAML /
/// `--stroke-width-range` on the CLI) to emit a variable font whose `wght`
/// axis is the literal stroke width. See `doc/variable_stroke.md`.
///
/// [IconData]: https://api.flutter.dev/flutter/widgets/IconData-class.html
///
/// {@category getting-started}
/// {@category cli}
/// {@category variable-stroke}
library;

export 'src/common.dart';
export 'src/job.dart';
export 'src/otf.dart';
export 'src/utils.dart';
