import '../otf.dart';
import '../utils/flutter_class_gen.dart';
import '../utils/logger.dart';
import 'generic_glyph.dart';

/// Result of svg-to-otf conversion.
///
/// Contains list of generated glyphs and created font.
class SvgToOtfResult {
  SvgToOtfResult._(this.glyphList, this.font);

  final List<GenericGlyph> glyphList;
  final OpenTypeFont font;
}

/// Converts SVG icons to OTF font.
///
/// * [svgMap] contains name (key) to data (value) SVG mapping. Required.
/// * If [outlineStrokes] is set to true, stroked paths are replaced by the
/// filled region their stroke covers. Defaults to true — font glyphs are
/// fill-only, so a stroked icon is otherwise invisible.
/// NOTE: Paint attributes other than stroke geometry (such as "fill" colour)
/// are ignored — only the shape's outline is used.
/// * If [normalize] is set to true, each glyph is scaled so that its own
/// longest side fills the em square, then centred. Defaults to false.
///
/// Normalization discards how much of its artboard an icon was drawn to
/// occupy, which is design information: a full-bleed circle and a small
/// arrow both end up the same size, inverting the set's proportions. With it
/// off, the artboard maps onto the em square directly and the relative sizes
/// the icons were drawn at survive — what an icon set almost always wants.
///
/// Turn it on only for icons collected from mismatched sources, where the
/// viewBoxes disagree and forcing a uniform size is the lesser evil.
/// * If [useOpenType] is set to true, the font carries OpenType (CFF)
/// outlines. Otherwise TrueType outlines are generated, which requires
/// approximating each cubic curve with quadratics. Defaults to true: CFF
/// stores cubics directly, so it is both smaller and exact.
/// * [fontName] is a name for a generated font.
///
/// Returns an instance of [SvgToOtfResult] class containing glyphs and a font.
SvgToOtfResult svgToOtf({
  required Map<String, String> svgMap,
  bool? outlineStrokes,
  bool? normalize,
  bool? useOpenType,
  String? fontName,
}) {
  normalize ??= false;

  final glyphList = [
    for (final e in svgMap.entries)
      GenericGlyph.fromSvg(
        e.key,
        e.value,
        outlineStrokes: outlineStrokes ?? true,
      ),
  ];

  if (!normalize) {
    for (var i = 1; i < glyphList.length; i++) {
      if (glyphList[i - 1].bounds.height != glyphList[i].bounds.height) {
        logger.logOnce(
          Level.warning,
          'Some SVG files contain different view box height, '
          'while normalization option is disabled. '
          'This is not recommended.',
        );
        break;
      }
    }
  }

  final font = OpenTypeFont.createFromGlyphs(
    glyphList: glyphList,
    fontName: fontName,
    normalize: normalize,
    useOpenType: useOpenType,
    usePostV2: false,
  );

  return SvgToOtfResult._(glyphList, font);
}

/// Generates a Flutter-compatible class for a list of glyphs.
///
/// * [glyphList] is a list of non-default glyphs.
/// * [className] is generated class' name (preferably, in PascalCase).
/// * [familyName] is font's family name to use in IconData.
/// * [package] is the name of a font package. Used to provide a font through package dependency.
/// * [fontFileName] is font file's name. Used in generated docs for class.
/// * [indent] is a number of spaces in leading indentation for class' members. Defaults to 2.
///
/// Returns content of a class file.
String generateFlutterClass({
  required List<GenericGlyph> glyphList,
  String? className,
  String? familyName,
  String? fontFileName,
  String? package,
  int? indent,
}) {
  final generator = FlutterClassGenerator(
    glyphList,
    className: className,
    indent: indent,
    fontFileName: fontFileName,
    familyName: familyName,
    package: package,
  );

  return generator.generate();
}
