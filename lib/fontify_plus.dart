/// Converts SVG icons into an OpenType font and generates a Flutter-compatible
/// class of [IconData] identifiers for them.
///
/// Start with [svgToOtf] to build the font, [writeToFile] to write it, and
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
/// A font glyph is a filled region — the format has no notion of stroke width,
/// caps or joins. Outline-style icon sets exported from Figma describe the
/// *centreline* of a stroke, which encloses no area and would render blank.
///
/// [svgToOtf] therefore converts stroked paths into the region the stroke
/// covers before encoding them. This is on by default; pass
/// `outlineStrokes: false` to treat path data as fill geometry instead.
///
/// [IconData]: https://api.flutter.dev/flutter/widgets/IconData-class.html
library;

export 'src/common.dart';
export 'src/otf.dart';
export 'src/svg.dart';
export 'src/utils.dart';
