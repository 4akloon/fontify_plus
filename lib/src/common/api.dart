import '../job/fontify_exception.dart';
import '../otf.dart';
import '../utils/flutter_class_gen.dart';
import '../utils/logger.dart';
import 'generic_glyph.dart';
import 'stroke_width_range.dart';

/// {@category api}
/// Result of svg-to-otf conversion.
///
/// Contains list of generated glyphs and created font.
class SvgToOtfResult {
  const SvgToOtfResult._(this.glyphList, this.font);

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
/// * [strokeWidthRange], when given, builds a *variable* font whose `wght`
/// axis is the icon's stroke width instead of one fixed width. Its `min`
/// and `max` are literal stroke widths in the SVG's own units — the same
/// units as its authored `stroke-width` — and [StrokeWidthRange.max] is the
/// font's default instance, the one every metric is computed from. Each
/// icon is built twice, once per end of the range, via [GlyphMasterBuilder].
/// Requires stroke outlining and OpenType: passing `outlineStrokes: false`
/// alongside it throws, because a fill does not depend on stroke width and
/// there would be nothing left to vary; passing `useOpenType: false`
/// alongside it throws too, because a TrueType variable font would need
/// `gvar`, which this package does not write. Omitted, the output is
/// unchanged from a font with no `strokeWidthRange` at all — down to the
/// byte.
///
/// Returns an instance of [SvgToOtfResult] class containing glyphs and a font.
SvgToOtfResult svgToOtf({
  required Map<String, String> svgMap,
  bool? outlineStrokes,
  bool? normalize,
  bool? useOpenType,
  String? fontName,
  StrokeWidthRange? strokeWidthRange,
}) {
  if (strokeWidthRange != null) {
    if (outlineStrokes == false) {
      throw const FontifyException(
        'strokeWidthRange needs stroked paths to vary, but outlineStrokes is '
        'false, which treats path data as fill geometry.',
      );
    }

    if (useOpenType == false) {
      throw const FontifyException(
        'strokeWidthRange requires OpenType (CFF2) outlines; the TrueType '
        'path has no variable form. Remove useOpenType: false.',
      );
    }
  }

  normalize ??= true;

  // Both branches build the same shape of [glyphList]; only the variable one
  // also produces [minGlyphList]. Keeping the no-range branch textually
  // identical to the code before this parameter existed is what keeps its
  // output byte-identical.
  final List<GenericGlyph> glyphList;
  final List<GenericGlyph>? minGlyphList;

  if (strokeWidthRange != null) {
    final masters = [
      for (final e in svgMap.entries)
        GlyphMasterBuilder(strokeWidthRange).fromSvg(e.key, e.value),
    ];

    // `glyphList` — the default master — carries the *maximum* width: it is
    // what `generateFlutterClass` reads charcodes from, and
    // `createFromGlyphs` assigns those charcodes to this list, not to
    // `minGlyphList`.
    glyphList = [for (final m in masters) m.max];
    minGlyphList = [for (final m in masters) m.min];
  } else {
    glyphList = [
      for (final e in svgMap.entries)
        GenericGlyph.fromSvg(
          e.key,
          e.value,
          outlineStrokes: outlineStrokes ?? true,
        ),
    ];
    minGlyphList = null;
  }

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
    minGlyphList: minGlyphList,
    strokeWidthRange: strokeWidthRange,
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
/// * [strokeWidthRange], when given, documents the variable `wght` axis in the class comment.
///
/// Returns content of a class file.
String generateFlutterClass({
  required List<GenericGlyph> glyphList,
  String? className,
  String? familyName,
  String? fontFileName,
  String? package,
  int? indent,
  StrokeWidthRange? strokeWidthRange,
}) {
  final generator = FlutterClassGenerator(
    glyphList,
    className: className,
    indent: indent,
    fontFileName: fontFileName,
    familyName: familyName,
    package: package,
    strokeWidthRange: strokeWidthRange,
  );

  return generator.generate();
}
