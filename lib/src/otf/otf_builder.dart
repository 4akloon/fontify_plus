import '../common/generic_glyph.dart';
import '../common/stroke_width_range.dart';
import '../utils/exception.dart';
import '../utils/misc.dart';
import '../utils/otf.dart';
import 'defaults.dart';
import 'glyph_fitting.dart';
import 'otf.dart';
import 'table/all.dart';

/// The `name` table ID `fvar`'s `axisNameID` and `STAT`'s `valueNameID`s
/// point at.
///
/// [kNameIDmap] covers every [NameID], so the lookup cannot miss; it is
/// nullable because the same map is also read the other way round, for IDs
/// arriving off the wire.
final _strokeWidthAxisNameID = kNameIDmap.getValueForKey(
  NameID.strokeWidthAxis,
)!;

/// Assembles an [OpenTypeFont] from a list of glyphs.
///
/// Mutates every [glyphList] glyph's metadata, so that it contains a newly
/// generated charcode. [minGlyphList] is left alone: `cmap` and `post` are
/// built from the default master, so the second master carries no charcode of
/// its own.
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
    this.minGlyphList,
    this.strokeWidthRange,
  }) : fontName = (fontName?.isEmpty ?? true) ? kDefaultFontFamily : fontName!,
       revision = revision ?? kDefaultFontRevision,
       achVendID = achVendID ?? kDefaultAchVendID,
       useOpenType = useOpenType ?? true,
       usePostV2 = usePostV2 ?? false,
       normalize = normalize ?? true {
    final minGlyphList = this.minGlyphList;

    // The two travel together or not at all: a second master with no axis to
    // put it on is data that would be silently dropped, and an axis with no
    // second master is a font whose every width interpolates to the same
    // drawing.
    if ((minGlyphList == null) != (strokeWidthRange == null)) {
      throw ArgumentError(
        'minGlyphList and strokeWidthRange must both be set or both be '
        'omitted; got minGlyphList: '
        '${minGlyphList == null ? 'null' : 'set'}, strokeWidthRange: '
        '${strokeWidthRange ?? 'null'}',
      );
    }

    if (minGlyphList != null && minGlyphList.length != glyphList.length) {
      throw ArgumentError(
        'glyphList and minGlyphList are indexed together and must have the '
        'same length; got ${glyphList.length} and ${minGlyphList.length}',
      );
    }

    // A TrueType variable font varies through `gvar`, which this package does
    // not write; there is no branch below that could honour the range. Task
    // 20 turns this into a user-facing `FontifyException` at the API surface.
    if (strokeWidthRange != null && !this.useOpenType) {
      throw ArgumentError(
        'strokeWidthRange requires useOpenType: true — TrueType outlines have '
        'no variable branch in this package',
      );
    }
  }

  final List<GenericGlyph> glyphList;
  final String fontName;
  final String? description;
  final Revision revision;
  final String achVendID;
  final bool useOpenType;
  final bool usePostV2;
  final bool normalize;

  /// The same glyphs as [glyphList], drawn at [StrokeWidthRange.min].
  ///
  /// Null for a static font. [glyphList] stays the *default* master — the
  /// maximum width — because that is the instance `fvar` selects by default
  /// and the one every metric below is computed from.
  final List<GenericGlyph>? minGlyphList;

  /// The stroke widths the font's `wght` axis spans, or null for a static
  /// font.
  final StrokeWidthRange? strokeWidthRange;

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

    // One placement per glyph, taken from the default master and applied to
    // both. `placementFor(g).apply(g)` reproduces `fit(g)` exactly, so the
    // static path's bytes are unchanged.
    final placements = [
      for (final glyph in glyphList) fitting.placementFor(glyph),
    ];

    final resizedGlyphList = [
      for (var i = 0; i < glyphList.length; i++)
        placements[i].apply(glyphList[i]),
    ];

    final minGlyphList = this.minGlyphList;

    final resizedMinGlyphList = minGlyphList == null
        ? null
        : [
            // The default master's transform, not each master's own: fitting
            // the thinner master independently would scale it up to fill the
            // same em band, which moves the centreline between the masters
            // and bends every interpolated width. It renders correctly at
            // both endpoints and subtly wrong everywhere else.
            for (var i = 0; i < minGlyphList.length; i++)
              placements[i].apply(minGlyphList[i]),
          ];

    final defaultGlyphList = generateDefaultGlyphList(ascender);
    final fullGlyphList = [...defaultGlyphList, ...resizedGlyphList];

    // The default glyphs (.notdef and space) are their own minimum master:
    // their deltas come out zero, which is what a glyph that does not vary
    // with stroke width should encode, and costs nothing because
    // `CharStringBlender.merge` emits no `blend` for an unvarying command.
    final fullMinGlyphList = resizedMinGlyphList == null
        ? null
        : [...defaultGlyphList, ...resizedMinGlyphList];

    // Every glyph's own bounding box — never overridden. hmtx.lsb, the head
    // bbox and hhea's rsb/extent all need the real xMin/xMax to stay
    // internally consistent (in particular, TrueType requires
    // hmtx.lsb == glyf.xMin); only the advance width has a legitimate reason
    // to differ from it, handled below via [advanceWidthOverrides].
    //
    // Only the default master is measured, on a variable font as well as a
    // static one. That is what makes `HVAR` unnecessary, and the reason is
    // that `hmtx` is written exactly once: with no per-region delta for an
    // instancer to apply, the advance is axis-invariant by construction.
    //
    // Not because the advance is the em square — it usually is not. With
    // `normalize: true` (the default) `advanceWidthOverrides` below is all
    // null, so `LongHorMetric.createForGlyph` uses each glyph's own ink
    // width: this package's four example icons advance by 947, 1000, 958 and
    // 1000, not by a uniform 1000. Only `normalize: false` pins every custom
    // glyph to `unitsPerEm`. What matters here is that either number is
    // taken from the default — widest — master and then frozen, so a thin
    // instance keeps the wide master's advance and gains sidebearing instead
    // of reflowing as the axis moves.
    //
    // `head`'s bounding box comes from the same measurement, which is again
    // the widest master's — the minimum master's ink is strictly inside it.
    final glyphMetricsList = [
      for (final glyph in defaultGlyphList) glyph.metrics,
      for (final glyph in resizedGlyphList) glyph.metrics,
    ];

    // Without normalization every custom glyph advances by the full em
    // regardless of how much of it its own ink fills — the artboard fitting
    // keeps a uniform grid instead of tightening around each icon.
    final advanceWidthOverrides = <int?>[
      ...List.filled(defaultGlyphList.length, null),
      ...List.filled(resizedGlyphList.length, normalize ? null : unitsPerEm),
    ];

    final tables = _buildTables(
      fullGlyphList: fullGlyphList,
      fullMinGlyphList: fullMinGlyphList,
      resizedGlyphList: resizedGlyphList,
      glyphMetricsList: glyphMetricsList,
      advanceWidthOverrides: advanceWidthOverrides,
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
    required List<GenericGlyph>? fullMinGlyphList,
    required List<GenericGlyph> resizedGlyphList,
    required List<GenericGlyphMetrics> glyphMetricsList,
    required List<int?> advanceWidthOverrides,
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

    // TrueType requires hmtx.lsb == glyf.xMin. glyphMetricsList's xMin comes
    // from each glyph's pre-cubicToQuad outline (see build()), but glyf's
    // own xMin — read here from the SimpleGlyph the encoder already built —
    // is computed from the post-conversion quadratic points, a different
    // point set whose bounding box need not coincide with the cubic one's.
    // Source lsb from glyf directly rather than reconciling the two metrics.
    //
    // CFF's charstrings are encoded straight from the same unconverted
    // cubic outlines glyphMetricsList reflects, so its lsb is left deriving
    // from glyphMetricsList unchanged — there is no second, divergent point
    // set to reconcile there.
    final lsbOverrides = glyf == null
        ? null
        : [for (final g in glyf.glyphList) g.isEmpty ? null : g.header.xMin];

    final hmtx = HorizontalMetricsTable.create(
      glyphMetricsList,
      unitsPerEm,
      advanceWidthOverrides: advanceWidthOverrides,
      lsbOverrides: lsbOverrides,
    );
    final hhea = HorizontalHeaderTable.create(
      glyphMetricsList,
      hmtx,
      ascender: ascender,
      descender: descender,
    );

    // Read once into a local: a public final field cannot be type-promoted,
    // and the three variable-only tables below all need the non-null range.
    final strokeWidthRange = this.strokeWidthRange;

    final name = NamingTable.create(
      fontName,
      description,
      revision,
      // A static font has no axis to name, and adding the record would move
      // every byte after it.
      axisName: strokeWidthRange == null ? null : kStrokeWidthAxisName,
    );

    if (name == null) {
      throw const TableDataFormatException('Unknown "name" table format');
    }

    final cmap = CharacterToGlyphTable.create(fullGlyphList);
    final gsub = GlyphSubstitutionTable.create();

    return <String, FontTable>{
      if (glyf != null) ...{
        kGlyfTag: glyf,
        kLocaTag: IndexToLocationTable.create(head.indexToLocFormat, glyf),
      },
      if (useOpenType && strokeWidthRange == null)
        kCFFTag: CFF1Table.create(fullGlyphList, head, hmtx, name),
      if (useOpenType && strokeWidthRange != null) ...{
        // CFF 1 has no way to carry a second master, so a variable font uses
        // CFF2 even though nothing else about the outlines changes.
        //
        // fullMinGlyphList is non-null exactly when the range is: build()
        // derives it from minGlyphList, and the constructor rejects either
        // one without the other.
        kCFF2Tag: CFF2Table.create([
          for (var i = 0; i < fullGlyphList.length; i++)
            [fullGlyphList[i], fullMinGlyphList![i]],
        ]),
        kFvarTag: FontVariationsTable.create(
          strokeWidthRange,
          axisNameID: _strokeWidthAxisNameID,
        ),
        kStatTag: StyleAttributesTable.create(
          strokeWidthRange,
          axisNameID: _strokeWidthAxisNameID,
        ),
      },
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
