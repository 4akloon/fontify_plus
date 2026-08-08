import '../common/generic_glyph.dart';
import '../utils/exception.dart';
import '../utils/misc.dart';
import '../utils/otf.dart';
import 'defaults.dart';
import 'glyph_fitting.dart';
import 'otf.dart';
import 'table/all.dart';

/// Assembles an [OpenTypeFont] from a list of glyphs.
///
/// Mutates every glyph's metadata, so that it contains a newly generated
/// charcode.
class OpenTypeFontBuilder {
  OpenTypeFontBuilder({
    required this.glyphList,
    String? fontName,
    this.description,
    Revision? revision,
    String? achVendID,
    bool? useOpenType,
    bool? usePostV2,
    bool? normalize,
  }) : fontName = (fontName?.isEmpty ?? true) ? kDefaultFontFamily : fontName!,
       revision = revision ?? kDefaultFontRevision,
       achVendID = achVendID ?? kDefaultAchVendID,
       useOpenType = useOpenType ?? true,
       usePostV2 = usePostV2 ?? false,
       normalize = normalize ?? false;

  final List<GenericGlyph> glyphList;
  final String fontName;
  final String? description;
  final Revision revision;
  final String achVendID;
  final bool useOpenType;
  final bool usePostV2;
  final bool normalize;

  /// A power of two is recommended only for TrueType outlines.
  int get _unitsPerEm =>
      useOpenType ? kDefaultOpenTypeUnitsPerEm : kDefaultTrueTypeUnitsPerEm;

  OpenTypeFont build() {
    _generateCharCodes();

    final unitsPerEm = _unitsPerEm;
    final baselineExtension = normalize ? kDefaultBaselineExtension : 0;
    final ascender = unitsPerEm - baselineExtension;
    final descender = -baselineExtension;

    final fitting = normalize
        ? NormalizedFitting(ascender: ascender, descender: descender)
        : ArtboardFitting(fontHeight: unitsPerEm);

    final resizedGlyphList = [
      for (final glyph in glyphList) fitting.fit(glyph),
    ];

    final defaultGlyphList = generateDefaultGlyphList(ascender);
    final fullGlyphList = [...defaultGlyphList, ...resizedGlyphList];

    final glyphMetricsList = [
      for (final glyph in defaultGlyphList) glyph.metrics,
      // If normalization is off every custom glyph's size equals unitsPerEm
      if (normalize)
        for (final glyph in resizedGlyphList) glyph.metrics
      else
        ...List.filled(
          resizedGlyphList.length,
          GenericGlyphMetrics.square(unitsPerEm),
        ),
    ];

    final tables = _buildTables(
      fullGlyphList: fullGlyphList,
      resizedGlyphList: resizedGlyphList,
      glyphMetricsList: glyphMetricsList,
      unitsPerEm: unitsPerEm,
      ascender: ascender,
      descender: descender,
    );

    return OpenTypeFont(
      OffsetTable.create(tables.length, useOpenType),
      tables,
    );
  }

  Map<String, FontTable> _buildTables({
    required List<GenericGlyph> fullGlyphList,
    required List<GenericGlyph> resizedGlyphList,
    required List<GenericGlyphMetrics> glyphMetricsList,
    required int unitsPerEm,
    required int ascender,
    required int descender,
  }) {
    final glyf = useOpenType ? null : GlyphDataTable.fromGlyphs(fullGlyphList);
    final head = HeaderTable.create(
      glyphMetricsList,
      glyf,
      revision,
      unitsPerEm,
    );
    final hmtx = HorizontalMetricsTable.create(glyphMetricsList, unitsPerEm);
    final hhea = HorizontalHeaderTable.create(
      glyphMetricsList,
      hmtx,
      ascender,
      descender,
    );

    final name = NamingTable.create(fontName, description, revision);

    if (name == null) {
      throw TableDataFormatException('Unknown "name" table format');
    }

    final cmap = CharacterToGlyphTable.create(fullGlyphList);
    final gsub = GlyphSubstitutionTable.create();

    return <String, FontTable>{
      if (glyf != null) ...{
        kGlyfTag: glyf,
        kLocaTag: IndexToLocationTable.create(head.indexToLocFormat, glyf),
      },
      if (useOpenType)
        kCFFTag: CFF1Table.create(fullGlyphList, head, hmtx, name),
      kCmapTag: cmap,
      kMaxpTag: MaximumProfileTable.create(fullGlyphList.length, glyf),
      kHeadTag: head,
      kHmtxTag: hmtx,
      kHheaTag: hhea,
      kPostTag: PostScriptTable.create(resizedGlyphList, usePostV2),
      kNameTag: name,
      kGSUBTag: gsub,
      kOS2Tag: OS2Table.create(hmtx, head, hhea, cmap, gsub, achVendID),
    };
  }

  void _generateCharCodes() {
    for (var i = 0; i < glyphList.length; i++) {
      glyphList[i].metadata.charCode = kUnicodePrivateUseAreaStart + i;
    }
  }
}
