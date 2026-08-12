import 'dart:convert';

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
/// * [defaultStrokeWidth] moves the axis's default off
/// [StrokeWidthRange.max] to a width strictly inside the range, so that a
/// font picker opens on that width and `STAT` gives it a name. Requires
/// [strokeWidthRange] — a width names a point *on* an axis, and with no
/// axis it would simply be dropped — and must not equal either end: at an
/// end it would describe a width the font already has, paying for a whole
/// extra variation region and telling a font picker two names for one
/// instance. Each icon is then built three times rather than twice, and
/// [SvgToOtfResult.glyphList] holds the *interior* drawing, since that is
/// the default instance every metric is computed from. Omitted, the default
/// stays at [StrokeWidthRange.max] and the output is byte-identical to a
/// build that never mentioned this parameter.
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
  StrokeWidthRange? strokeWidthRange,
  double? defaultStrokeWidth,
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

  // Checked here, and again in `OpenTypeFontBuilder`, on purpose. That
  // constructor is a public boundary of its own and raises `ArgumentError`,
  // which is the right vocabulary for a programming error against a builder;
  // this function's own vocabulary is `FontifyException`, the one its two
  // checks above already speak and the one the CLI knows how to report. A
  // caller who misconfigures the axis here should be told so in the same
  // terms as a caller who misconfigures `outlineStrokes`, not by an
  // `ArgumentError` surfacing from inside a class they never named.
  if (defaultStrokeWidth != null) {
    if (strokeWidthRange == null) {
      throw FontifyException(
        'defaultStrokeWidth names a width on the stroke-width axis, but '
        'without strokeWidthRange there is no axis to put it on and the '
        'value would be silently dropped; got defaultStrokeWidth: '
        '$defaultStrokeWidth.',
      );
    }

    // A negated conjunction rather than two comparisons, so that a NaN width
    // — which loses every ordering test it is given — falls into the error
    // rather than out of it.
    if (!(strokeWidthRange.min < defaultStrokeWidth &&
        defaultStrokeWidth < strokeWidthRange.max)) {
      throw FontifyException(
        'defaultStrokeWidth must lie strictly between the ends of '
        'strokeWidthRange: outside them the font would default to a width '
        'no master was drawn at, and at either end the third master would '
        'duplicate the endpoint it sits on; got defaultStrokeWidth: '
        '$defaultStrokeWidth, strokeWidthRange: $strokeWidthRange.',
      );
    }
  }

  normalize ??= true;
  final embedPreview = preview ?? true;

  // Both branches build the same shape of [glyphList]; only the variable one
  // also produces [minGlyphList] and [maxGlyphList]. Keeping the no-range
  // branch textually identical to the code before these parameters existed is
  // what keeps its output byte-identical.
  final List<GenericGlyph> glyphList;
  final List<GenericGlyph>? minGlyphList;
  final List<GenericGlyph>? maxGlyphList;

  if (strokeWidthRange != null) {
    final masters = [
      for (final e in svgMap.entries)
        GlyphMasterBuilder(
          strokeWidthRange,
          defaultWidth: defaultStrokeWidth,
        ).fromSvg(e.key, e.value),
    ];

    // `glyphList` is the *default* master whichever width that turns out to
    // be: the interior drawing when one was asked for, the maximum otherwise.
    // It is the list `createFromGlyphs` assigns charcodes to — never
    // `minGlyphList` or `maxGlyphList` — and therefore the list
    // `generateFlutterClass` can read them back from, so the preview blobs
    // below belong on it too.
    glyphList = [for (final m in masters) m.atDefault ?? m.max];
    minGlyphList = [for (final m in masters) m.min];

    // Needed exactly when the default moved inwards: the axis then has a
    // maximum with no master of its own, and `OpenTypeFontBuilder` rejects
    // either half of that pair without the other.
    maxGlyphList = defaultStrokeWidth == null
        ? null
        : [for (final m in masters) m.max];

    if (embedPreview) {
      var i = 0;
      for (final e in svgMap.entries) {
        glyphList[i].metadata.preview = base64Encode(utf8.encode(e.value));
        i++;
      }
    }
  } else {
    glyphList = [
      for (final e in svgMap.entries)
        GenericGlyph.fromSvg(
          e.key,
          e.value,
          outlineStrokes: outlineStrokes ?? true,
          preview: embedPreview,
        ),
    ];
    minGlyphList = null;
    maxGlyphList = null;
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
    created: created,
    modified: modified,
    minGlyphList: minGlyphList,
    maxGlyphList: maxGlyphList,
    strokeWidthRange: strokeWidthRange,
    defaultStrokeWidth: defaultStrokeWidth,
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
