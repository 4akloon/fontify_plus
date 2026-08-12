import 'dart:typed_data';

import '../common/calculatable_offsets.dart';
import '../common/codable/binary.dart';
import '../common/generic_glyph.dart';
import '../common/stroke_width_range.dart';
import '../utils/otf.dart';
import 'font_tables.dart';
import 'otf_builder.dart';
import 'reader.dart';
import 'table/all.dart';

export 'defaults.dart' show kDefaultFontTimestamp;

/// Ordered list of table tags for encoding (Optimized Table Ordering)
///
/// Anything in [OpenTypeFont.tableMap] whose tag is not listed here is
/// silently skipped by [_encodeTables] — no error, no log line. (The read
/// side is not this quiet: an unhandled tag in `reader.dart`'s
/// `_createTableFromEntry` does log a warning before dropping the table —
/// see that file.) `kFvarTag` ('fvar') and `kStatTag` ('STAT') are listed
/// here; placement within the set doesn't matter, since
/// [OpenTypeFont.encodeToBinary] sorts the directory entries by tag before
/// writing them, regardless of this set's iteration order. A new
/// table still needs an entry here, and a matching case in `reader.dart`,
/// or it will be silently dropped on write and (audibly, but still
/// dropped) on read.
const _kTableTagsToEncode = {
  kHeadTag,
  kHheaTag,
  kMaxpTag,
  kOS2Tag,
  kHmtxTag,
  kNameTag, // NOTE: 'name' should be after 'cmap' for TTF
  kCmapTag,
  kLocaTag,
  kGlyfTag,
  kPostTag,
  kCFFTag,
  kCFF2Tag,
  kGSUBTag,
  kFvarTag,
  kStatTag,
};

/// A private-symbol alias for `table_registration_test.dart`, not additional
/// public API.
///
/// `_kTableTagsToEncode` needs to be reachable from a test without becoming
/// a public constant. `@visibleForTesting` was avoided because `meta` is
/// only a transitive dependency of this package (present in `pubspec.lock`
/// via other packages, absent from `pubspec.yaml`), and using it here would
/// add a direct dependency for one annotation. Instead, `lib/src/otf.dart`
/// hides this name from its `export 'otf/otf.dart'` directive, so it never
/// reaches
/// `package:fontify_plus/fontify_plus.dart`; the test imports
/// `package:fontify_plus/src/otf/otf.dart` directly to reach it, the same
/// way other tests in this repo reach non-exported internals.
const debugTableTagsToEncode = _kTableTagsToEncode;

/// {@category api}
/// An OpenType font.
/// Contains either TrueType (glyf table) or OpenType (CFF2 table) outlines
class OpenTypeFont implements BinaryCodable {
  OpenTypeFont(this.offsetTable, Map<String, FontTable> tableMap)
    : tables = FontTables(tableMap);

  factory OpenTypeFont.fromByteData(ByteData byteData) =>
      OTFReader.fromByteData(byteData).read();

  /// Generates new OpenType font.
  ///
  /// Mutates every [glyphList] glyph's metadata,
  /// so that it contains newly generated charcode. [minGlyphList], when
  /// given, is left alone.
  ///
  /// * [glyphList] is a list of generic glyphs. Required.
  /// * [fontName] is a font name.
  /// * [description] is a font description for naming table.
  /// * [revision] is a font revision. Defaults to 1.0.
  /// * [achVendID] is a vendor ID in OS/2 table. Defaults to 4 spaces.
  /// * If [useOpenType] is set to true, OpenType outlines
  /// in CFF table format are generated.
  /// Otherwise, a font with TrueType outlines (TTF) is generated.
  /// Defaults to true.
  /// * If [usePostV2] is set to true, post table of version 2 is generated
  /// (containing a name for each glyph).
  /// Otherwise, version 3 table (without glyph names) is generated.
  /// Defaults to false.
  /// * If [normalize] is set to true, each glyph is scaled so that its own
  /// longest side fills the em square, then centred. Defaults to true —
  /// see `GlyphFitting`.
  /// * [created] / [modified] are written to the `head` table. Omit both to
  /// use [kDefaultFontTimestamp]; when regenerating over an existing file,
  /// pass the previous font's dates to keep bytes stable.
  /// * [minGlyphList] is the same glyphs as [glyphList], drawn at the
  /// minimum of [strokeWidthRange]. Supplying it makes the font *variable*:
  /// the outlines move to a `CFF2` table carrying both masters, and `fvar`
  /// and `STAT` declare a `wght` axis whose values are literal stroke
  /// widths. [glyphList] stays the default master (the maximum width),
  /// which is the instance `fvar` selects and the one every metric is
  /// computed from. Both lists are indexed together and must have the same
  /// length. Omitted for a static font.
  /// * [strokeWidthRange] is the span that axis covers. It must be given
  /// exactly when [minGlyphList] is — a second master with no axis would be
  /// dropped, an axis with no second master would vary nothing — and it
  /// requires `useOpenType: true`, since a TrueType variable font would need
  /// `gvar`, which this package does not write.
  ///
  /// Throws [ArgumentError] for any of those combinations.
  factory OpenTypeFont.createFromGlyphs({
    required List<GenericGlyph> glyphList,
    String? fontName,
    String? description,
    Revision? revision,
    String? achVendID,
    bool? useOpenType,
    bool? usePostV2,
    bool? normalize,
    DateTime? created,
    DateTime? modified,
    List<GenericGlyph>? minGlyphList,
    StrokeWidthRange? strokeWidthRange,
  }) => OpenTypeFontBuilder(
    glyphList: glyphList,
    fontName: fontName,
    description: description,
    revision: revision,
    achVendID: achVendID,
    useOpenType: useOpenType,
    usePostV2: usePostV2,
    normalize: normalize,
    created: created,
    modified: modified,
    minGlyphList: minGlyphList,
    strokeWidthRange: strokeWidthRange,
  ).build();

  final OffsetTable offsetTable;

  /// This font's tables, addressed by tag with the type checked.
  final FontTables tables;

  /// Every table keyed by its tag, for callers that iterate or count them.
  ///
  /// Read-only; reach for the named getters below, or [FontTables.lookup] /
  /// [FontTables.require] on [tables], to get at one table in particular.
  Map<String, FontTable> get tableMap => tables.asMap;

  // Tables every font must carry. Asking for one a font does not have is a
  // malformed font, so these report the missing tag rather than return null.
  HeaderTable get head => tables.require<HeaderTable>(kHeadTag);
  MaximumProfileTable get maxp => tables.require<MaximumProfileTable>(kMaxpTag);
  GlyphSubstitutionTable get gsub =>
      tables.require<GlyphSubstitutionTable>(kGSUBTag);
  OS2Table get os2 => tables.require<OS2Table>(kOS2Tag);
  PostScriptTable get post => tables.require<PostScriptTable>(kPostTag);
  NamingTable get name => tables.require<NamingTable>(kNameTag);
  CharacterToGlyphTable get cmap =>
      tables.require<CharacterToGlyphTable>(kCmapTag);
  HorizontalHeaderTable get hhea =>
      tables.require<HorizontalHeaderTable>(kHheaTag);
  HorizontalMetricsTable get hmtx =>
      tables.require<HorizontalMetricsTable>(kHmtxTag);

  // Tables that depend on the outline format or on the font being variable.
  // A CFF font genuinely has no glyf and no loca, a TrueType font has no CFF,
  // and a static font has neither fvar nor STAT; the null says so.

  /// The glyph outlines, on a TrueType font — null on a CFF one.
  GlyphDataTable? get glyf => tables.lookup<GlyphDataTable>(kGlyfTag);

  /// The glyph offsets into [glyf], on a TrueType font — null on a CFF one.
  IndexToLocationTable? get loca => tables.lookup<IndexToLocationTable>(
    kLocaTag,
  );

  /// The CFF 1 outlines, on an OpenType/CFF font — null otherwise.
  CFF1Table? get cff => tables.lookup<CFF1Table>(kCFFTag);

  /// The CFF 2 outlines, on a variable OpenType/CFF font — null otherwise.
  CFF2Table? get cff2 => tables.lookup<CFF2Table>(kCFF2Tag);

  /// The variation axes, on a variable font — null on a static one.
  FontVariationsTable? get fvar => tables.lookup<FontVariationsTable>(kFvarTag);

  /// The style attributes, on a variable font — null on a static one.
  StyleAttributesTable? get stat => tables.lookup<StyleAttributesTable>(
    kStatTag,
  );

  bool get isOpenType => offsetTable.isOpenType;

  String get familyName => name.familyName;

  int get entryListSize => kTableRecordEntryLength * tableMap.length;

  int get tableListSize =>
      tableMap.values.fold<int>(0, (p, t) => p + getPaddedTableSize(t.size));

  @override
  int get size => kOffsetTableLength + entryListSize + tableListSize;

  @override
  void encodeToBinary(ByteData byteData) {
    final entryList = _encodeTables(byteData);

    // The directory entry tags must be in ascending order
    entryList.sort((e1, e2) => e1.tag.compareTo(e2.tag));

    for (var i = 0; i < entryList.length; i++) {
      final entryOffset = kOffsetTableLength + i * kTableRecordEntryLength;

      entryList[i].encodeToBinary(
        byteData.sublistView(entryOffset, kTableRecordEntryLength),
      );
    }

    offsetTable.encodeToBinary(byteData.sublistView(0, kOffsetTableLength));

    // Setting checksum for whole font in the head table
    byteData.setUint32(head.entry!.offset + 8, calculateFontChecksum(byteData));
  }

  /// Writes every table in encoding order, returning their directory entries.
  List<TableRecordEntry> _encodeTables(ByteData byteData) {
    var currentTableOffset = kOffsetTableLength + entryListSize;

    final entryList = <TableRecordEntry>[];

    for (final tag in _kTableTagsToEncode) {
      final table = tableMap[tag];

      if (table == null) {
        continue;
      }

      // A pattern rather than `is` plus a cast: `CalculatableOffsets` is not
      // a subtype of `FontTable`, so an `is` test cannot promote `table` and
      // the code had to re-state the type with `as` on the very next line.
      // The pattern binds an already-typed name from the same runtime check.
      if (table case final CalculatableOffsets calculatable) {
        calculatable.recalculateOffsets();
      }

      final tableSize = table.size;

      table.encodeToBinary(byteData.sublistView(currentTableOffset, tableSize));

      final encodedTable = ByteData.sublistView(
        byteData,
        currentTableOffset,
        currentTableOffset + tableSize,
      );

      table.entry = TableRecordEntry(
        tag,
        checkSum: calculateTableChecksum(encodedTable),
        offset: currentTableOffset,
        length: tableSize,
      );
      entryList.add(table.entry!);

      currentTableOffset += getPaddedTableSize(tableSize);
    }

    return entryList;
  }
}
