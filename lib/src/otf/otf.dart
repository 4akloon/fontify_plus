import 'dart:typed_data';

import '../common/calculatable_offsets.dart';
import '../common/codable/binary.dart';
import '../common/generic_glyph.dart';
import '../utils/otf.dart';
import 'otf_builder.dart';
import 'reader.dart';
import 'table/all.dart';

/// Ordered list of table tags for encoding (Optimized Table Ordering)
///
/// Anything in [OpenTypeFont.tableMap] whose tag is not listed here is
/// silently skipped by [_encodeTables] — no error, no log line. In
/// particular, `kFvarTag` ('fvar') and `kStatTag` ('STAT') are NOT listed:
/// whichever change wires the variable-width axis into the builder MUST add
/// both here, or the encoder will produce a static-looking font that quietly
/// carries no axis. See also the `default:` case in `reader.dart`'s
/// `_createTableFromEntry`, which has the same gap on the read side.
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
};

/// {@category api}
/// An OpenType font.
/// Contains either TrueType (glyf table) or OpenType (CFF2 table) outlines
class OpenTypeFont implements BinaryCodable {
  OpenTypeFont(this.offsetTable, this.tableMap);

  factory OpenTypeFont.fromByteData(ByteData byteData) =>
      OTFReader.fromByteData(byteData).read();

  /// Generates new OpenType font.
  ///
  /// Mutates every glyph's metadata,
  /// so that it contains newly generated charcode.
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
  factory OpenTypeFont.createFromGlyphs({
    required List<GenericGlyph> glyphList,
    String? fontName,
    String? description,
    Revision? revision,
    String? achVendID,
    bool? useOpenType,
    bool? usePostV2,
    bool? normalize,
  }) => OpenTypeFontBuilder(
    glyphList: glyphList,
    fontName: fontName,
    description: description,
    revision: revision,
    achVendID: achVendID,
    useOpenType: useOpenType,
    usePostV2: usePostV2,
    normalize: normalize,
  ).build();

  final OffsetTable offsetTable;
  final Map<String, FontTable> tableMap;

  HeaderTable get head => tableMap[kHeadTag] as HeaderTable;
  MaximumProfileTable get maxp => tableMap[kMaxpTag] as MaximumProfileTable;
  IndexToLocationTable get loca => tableMap[kLocaTag] as IndexToLocationTable;
  GlyphDataTable get glyf => tableMap[kGlyfTag] as GlyphDataTable;
  GlyphSubstitutionTable get gsub =>
      tableMap[kGSUBTag] as GlyphSubstitutionTable;
  OS2Table get os2 => tableMap[kOS2Tag] as OS2Table;
  PostScriptTable get post => tableMap[kPostTag] as PostScriptTable;
  NamingTable get name => tableMap[kNameTag] as NamingTable;
  CharacterToGlyphTable get cmap => tableMap[kCmapTag] as CharacterToGlyphTable;
  HorizontalHeaderTable get hhea => tableMap[kHheaTag] as HorizontalHeaderTable;
  HorizontalMetricsTable get hmtx =>
      tableMap[kHmtxTag] as HorizontalMetricsTable;
  CFF1Table get cff => tableMap[kCFFTag] as CFF1Table;
  CFF2Table get cff2 => tableMap[kCFF2Tag] as CFF2Table;

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

      if (table is CalculatableOffsets) {
        (table as CalculatableOffsets).recalculateOffsets();
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
        calculateTableChecksum(encodedTable),
        currentTableOffset,
        tableSize,
      );
      entryList.add(table.entry!);

      currentTableOffset += getPaddedTableSize(tableSize);
    }

    return entryList;
  }
}
