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
/// generated charcode. [minGlyphList] and [maxGlyphList] are left alone:
/// `cmap` and `post` are built from the default master, so the other masters
/// carry no charcode of their own.
class OpenTypeFontBuilder {
  /// Rejects, with an [ArgumentError] naming the offending combination, any
  /// set of masters and axis values that cannot describe one font.
  ///
  /// This is where [defaultStrokeWidth] is checked against
  /// [strokeWidthRange]. Nothing downstream re-checks it: `fvar`, `STAT` and
  /// `GlyphMasterBuilder` each document that they trust their caller, because
  /// a table encoder is handed an already-decided font description rather
  /// than being the boundary a value arrives through. This constructor *is*
  /// such a boundary — it is public API — so it does not trust its callers
  /// either, even though the higher-level entry points re-state the same
  /// rules in their own vocabulary before getting here.
  OpenTypeFontBuilder({
    required this.glyphList,
    String? fontName,
    this.description,
    Revision? revision,
    String? achVendID,
    bool? useOpenType,
    bool? usePostV2,
    bool? normalize,
    this.created,
    this.modified,
    this.minGlyphList,
    this.maxGlyphList,
    this.strokeWidthRange,
    this.defaultStrokeWidth,
  }) : fontName = (fontName?.isEmpty ?? true) ? kDefaultFontFamily : fontName!,
       revision = revision ?? kDefaultFontRevision,
       achVendID = achVendID ?? kDefaultAchVendID,
       useOpenType = useOpenType ?? true,
       usePostV2 = usePostV2 ?? false,
       normalize = normalize ?? true {
    // Read into locals so the null tests below promote them: a public final
    // field cannot be type-promoted, and every rule here is phrased in terms
    // of one of these being present or absent.
    final minGlyphList = this.minGlyphList;
    final maxGlyphList = this.maxGlyphList;
    final strokeWidthRange = this.strokeWidthRange;
    final defaultStrokeWidth = this.defaultStrokeWidth;

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

    // A default width names a point *on* an axis, so there has to be an axis
    // for it to name. Without one it would be silently dropped: the static
    // path writes neither `fvar` nor `STAT`, and nothing else reads it.
    if (defaultStrokeWidth != null && strokeWidthRange == null) {
      throw ArgumentError(
        'defaultStrokeWidth requires strokeWidthRange; got '
        'defaultStrokeWidth: $defaultStrokeWidth, strokeWidthRange: null',
      );
    }

    // Strict on both sides, and both kinds of violation are silent
    // downstream. Outside the range, `fvar` writes a default coordinate the
    // masters do not sit at, so the font parses and sanitizes and is wrong
    // only once something renders it. Equal to an endpoint, the third master
    // duplicates the endpoint master it sits on: the font pays for a second
    // variation region and a second delta behind every blended value to
    // describe a width it already had, and `STAT` names two axis values at
    // one coordinate, which tells a font picker two names for one instance.
    //
    // Written as a negated conjunction rather than as two comparisons so a
    // NaN width — which loses every ordering test it is given — falls into
    // the error rather than out of it.
    if (strokeWidthRange != null &&
        defaultStrokeWidth != null &&
        !(strokeWidthRange.min < defaultStrokeWidth &&
            defaultStrokeWidth < strokeWidthRange.max)) {
      throw ArgumentError(
        'defaultStrokeWidth must lie strictly between the ends of '
        'strokeWidthRange; got defaultStrokeWidth: $defaultStrokeWidth, '
        'strokeWidthRange: $strokeWidthRange',
      );
    }

    // A third master exists only to let the default instance sit at an
    // interior width: it is the drawing at the *maximum*, which [glyphList]
    // stops being once [defaultStrokeWidth] takes over as the default. With
    // no minimum master there is no axis for it to be an end of, and with no
    // interior default [glyphList] is already the maximum, so the third
    // master would be a duplicate that costs a whole extra variation region.
    if (maxGlyphList != null &&
        (minGlyphList == null || defaultStrokeWidth == null)) {
      final missing = [
        if (minGlyphList == null) 'minGlyphList',
        if (defaultStrokeWidth == null) 'defaultStrokeWidth',
      ];

      throw ArgumentError(
        'maxGlyphList is the third master, drawn at the maximum of '
        'strokeWidthRange while glyphList is drawn at defaultStrokeWidth, so '
        'it cannot stand alone; got maxGlyphList: set, but '
        '${missing.join(' and ')}: null',
      );
    }

    if (minGlyphList != null && minGlyphList.length != glyphList.length) {
      throw ArgumentError(
        'glyphList and minGlyphList are indexed together and must have the '
        'same length; got ${glyphList.length} and ${minGlyphList.length}',
      );
    }

    if (maxGlyphList != null && maxGlyphList.length != glyphList.length) {
      throw ArgumentError(
        'glyphList and maxGlyphList are indexed together and must have the '
        'same length; got ${glyphList.length} and ${maxGlyphList.length}',
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
  final DateTime? created;
  final DateTime? modified;

  /// The same glyphs as [glyphList], drawn at [StrokeWidthRange.min].
  ///
  /// Null for a static font. [glyphList] stays the *default* master, whatever
  /// else changes: it is the instance `fvar` selects by default, and the one
  /// every metric below is computed from.
  ///
  /// Which stroke width that master is drawn at depends on [maxGlyphList].
  /// With no third master the default sits at the axis maximum, so
  /// [glyphList] holds the widest drawing. With one, the default sits at
  /// [defaultStrokeWidth] — an interior width — and [glyphList] holds *that*
  /// drawing while [maxGlyphList] holds the widest.
  final List<GenericGlyph>? minGlyphList;

  /// The same glyphs as [glyphList], drawn at [StrokeWidthRange.max].
  ///
  /// Null unless the default instance sits at an interior width, which is the
  /// only case where the maximum needs a master of its own: otherwise
  /// [glyphList] already is that drawing.
  ///
  /// An interior default puts normalized design space at -1 → 0 → +1 instead
  /// of -1 → 0, and a variation region's scalar is zero outside its own span,
  /// so widths above the default need a second region — and a master at the
  /// far end of it — to vary at all. Supplying this list is what makes the
  /// `CFF2` variation store two-region.
  ///
  /// Requires [minGlyphList] and [defaultStrokeWidth]; see the constructor.
  final List<GenericGlyph>? maxGlyphList;

  /// The stroke widths the font's `wght` axis spans, or null for a static
  /// font.
  final StrokeWidthRange? strokeWidthRange;

  /// The width the axis defaults to, or null to default to
  /// [StrokeWidthRange.max].
  ///
  /// Must lie strictly between the range's ends, and requires
  /// [strokeWidthRange]; see the constructor for both rules and why they are
  /// enforced here rather than downstream.
  ///
  /// It is written as `fvar`'s default axis coordinate and named by a `STAT`
  /// axis value of its own, and it is the width [glyphList] is expected to be
  /// drawn at whenever [maxGlyphList] is supplied. This class cannot check
  /// that last part — one drawing of a glyph looks like any other from here —
  /// so it is a contract with the caller, not an invariant.
  final double? defaultStrokeWidth;

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
    // every master there is. `placementFor(g).apply(g)` reproduces `fit(g)`
    // exactly, so the static path's bytes are unchanged.
    final placements = [
      for (final glyph in glyphList) fitting.placementFor(glyph),
    ];

    final resizedGlyphList = [
      for (var i = 0; i < glyphList.length; i++)
        placements[i].apply(glyphList[i]),
    ];

    // Applies the default master's placements to one of the other masters.
    //
    // The default master's transform, not each master's own: fitting a
    // narrower or wider master independently would scale it to fill the same
    // em band, which moves the centreline between the masters and bends
    // every interpolated width. It renders correctly at each master's own
    // width and subtly wrong everywhere else. One function rather than a
    // derivation per master, so no master can be given a different rule by
    // accident.
    List<GenericGlyph>? resizeAlongsideDefault(List<GenericGlyph>? master) =>
        master == null
        ? null
        : [
            for (var i = 0; i < master.length; i++)
              placements[i].apply(master[i]),
          ];

    final resizedMinGlyphList = resizeAlongsideDefault(minGlyphList);
    final resizedMaxGlyphList = resizeAlongsideDefault(maxGlyphList);

    final defaultGlyphList = generateDefaultGlyphList(ascender);
    final fullGlyphList = [...defaultGlyphList, ...resizedGlyphList];

    // Prepends the default glyphs, which every master shares verbatim.
    //
    // The default glyphs (.notdef and space) are their own master at every
    // width: their deltas come out zero, which is what a glyph that does not
    // vary with stroke width should encode, and costs nothing because
    // `CharStringBlender.merge` emits no `blend` for an unvarying command.
    List<GenericGlyph>? withDefaultGlyphs(List<GenericGlyph>? resized) =>
        resized == null ? null : [...defaultGlyphList, ...resized];

    final fullMinGlyphList = withDefaultGlyphs(resizedMinGlyphList);
    final fullMaxGlyphList = withDefaultGlyphs(resizedMaxGlyphList);

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
    // taken from the default master and then frozen, so every other instance
    // keeps that master's advance and gains or loses sidebearing instead of
    // reflowing as the axis moves.
    //
    // `head`'s bounding box comes from the same measurement. With no third
    // master the default is the widest drawing, so the box encloses every
    // instance's ink outright. With one it does not: `maxGlyphList`'s ink
    // extends a few percent past it. That is a tolerated understatement
    // rather than a bug — `head`'s box is advisory, used for cache sizing,
    // and the alternative is either measuring a master that is not the
    // default (making the box disagree with `hmtx`, which must stay the
    // default's) or writing `HVAR` to vary the metrics, which is a much
    // larger change than the box is worth.
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
      fullMaxGlyphList: fullMaxGlyphList,
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
    required List<GenericGlyph>? fullMaxGlyphList,
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
      created: created,
      modified: modified,
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

    // Read once into a local for a second reason: `fvar` and `STAT` below
    // must be given the *same* default. `fvar` writes it as the axis's
    // default coordinate and `STAT` names it as an axis value, so a font
    // whose two tables disagree opens on an instance style matching has no
    // name for — and nothing rejects that font, it simply behaves oddly in a
    // font picker. The two `create` calls sit five lines apart, which is far
    // enough that writing the value out twice is how they would drift; there
    // is one name and both read it.
    final defaultStrokeWidth = this.defaultStrokeWidth;

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
        //
        // Master order is load-bearing and not merely conventional:
        // `CharStringBlender` writes one delta per master after the default,
        // in this order, and `Cff2RegionContext` pairs those deltas with the
        // variation store's regions positionally — region 0 spans -1 to 0 and
        // peaks at the axis minimum, region 1 spans 0 to +1 and peaks at the
        // maximum. So the minimum-width master must come second and the
        // maximum-width one third. Swapped, every delta would still encode
        // and the font would still sanitize; it would just interpolate the
        // wrong way along the axis.
        kCFF2Tag: CFF2Table.create([
          for (var i = 0; i < fullGlyphList.length; i++)
            [
              fullGlyphList[i],
              fullMinGlyphList![i],
              // Absent, rather than null or empty, when there is no third
              // master: CFF2Table.create reads the master count per glyph and
              // sizes the whole table's variation store from it.
              if (fullMaxGlyphList != null) fullMaxGlyphList[i],
            ],
        ]),
        kFvarTag: FontVariationsTable.create(
          strokeWidthRange,
          defaultWidth: defaultStrokeWidth,
          axisNameID: _strokeWidthAxisNameID,
        ),
        kStatTag: StyleAttributesTable.create(
          strokeWidthRange,
          defaultWidth: defaultStrokeWidth,
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
