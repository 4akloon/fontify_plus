import '../otf.dart';
import '../utils/flutter_class_gen.dart';
import '../utils/logger.dart';
import 'generic_glyph.dart';

/// {@category api}
/// Result of svg-to-otf conversion.
///
/// Contains list of generated glyphs and created font.
class SvgToOtfResult {
  SvgToOtfResult._(this.glyphList, this.font);

  final List<GenericGlyph> glyphList;
  final OpenTypeFont font;
}

/// {@category api}
/// {@category stroked-icons}
/// {@category glyph-sizing}
/// Converts SVG icons to OTF font.
///
/// * [svgMap] contains name (key) to data (value) SVG mapping. Required.
/// * If [outlineStrokes] is set to true, stroked paths are replaced by the
/// filled region their stroke covers. Defaults to true — font glyphs are
/// fill-only, so a stroked icon is otherwise invisible.
/// * If [preview] is set to true, each glyph stores a base64-encoded copy of
/// its input SVG for dartdoc previews in the generated `IconData` class.
/// Defaults to true.
/// NOTE: Paint attributes other than stroke geometry (such as "fill" colour)
/// are ignored — only the shape's outline is used.
/// * If [normalize] is set to true, each glyph is scaled so that its own
/// longest side fills the em square, then centred. Defaults to true — icons
/// from mismatched sources then share a uniform visual size in `Icon`.
///
/// Normalization discards how much of its artboard an icon was drawn to
/// occupy. Pass `normalize: false` (or `--no-normalize`) when every icon
/// shares a viewBox and relative artboard occupancy is intentional: the
/// artboard then maps onto the em square directly.
/// * If [useOpenType] is set to true, the font carries OpenType (CFF)
/// outlines. Otherwise TrueType outlines are generated, which requires
/// approximating each cubic curve with quadratics. Defaults to true: CFF
/// stores cubics directly, so it is both smaller and exact.
/// * [fontName] is a name for a generated font.
/// * [created] / [modified] are written into the font `head` table. When
/// rewriting an existing `.otf`, pass the previous values to avoid churn.
///
/// Returns an instance of [SvgToOtfResult] class containing glyphs and a font.
SvgToOtfResult svgToOtf({
  required Map<String, String> svgMap,
  bool? outlineStrokes,
  bool? preview,
  bool? normalize,
  bool? useOpenType,
  String? fontName,
  DateTime? created,
  DateTime? modified,
}) {
  normalize ??= true;

  final glyphList = [
    for (final e in svgMap.entries)
      GenericGlyph.fromSvg(
        e.key,
        e.value,
        outlineStrokes: outlineStrokes ?? true,
        preview: preview ?? true,
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
    created: created,
    modified: modified,
  );

  return SvgToOtfResult._(glyphList, font);
}

/// {@category api}
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
