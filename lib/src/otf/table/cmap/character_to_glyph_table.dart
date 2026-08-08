import 'dart:typed_data';

import '../../../common/generic_glyph.dart';
import '../../../utils/otf.dart';
import '../abstract.dart';
import '../table_record_entry.dart';
import 'cmap_data.dart';
import 'cmap_format.dart';
import 'cmap_header.dart';
import 'cmap_segment.dart';
import 'encoding_record.dart';

/// Encoding records to write, ordered by platform and encoding ID.
List<EncodingRecord> _defaultEncodingRecords() => [
  /// Unicode (2.0 or later semantics BMP only), format 4
  EncodingRecord.create(kPlatformUnicode, 3),

  /// Unicode (2.0 or later semantics, non-BMP allowed), format 12
  EncodingRecord.create(kPlatformUnicode, 4),

  /// Macintosh, format 0
  EncodingRecord.create(kPlatformMacintosh, 0),

  /// Windows (Unicode BMP-only UCS-2), format 4
  EncodingRecord.create(kPlatformWindows, 1),

  /// Windows (Unicode UCS-4), format 12
  EncodingRecord.create(kPlatformWindows, 10),
];

/// Subtable format for each record above, in the same order.
const _kDefaultEncodingRecordFormatList = [
  kCmapFormat4,
  kCmapFormat12,
  kCmapFormat0,
  kCmapFormat4,
  kCmapFormat12,
];

/// The `cmap` table: which character code selects which glyph.
class CharacterToGlyphTable extends FontTable {
  CharacterToGlyphTable(super.entry, this.header, this.data)
    : super.fromTableRecordEntry();

  factory CharacterToGlyphTable.fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
  ) {
    final header = CharacterToGlyphTableHeader.fromByteData(byteData, entry);

    final data = List.generate(
      header.numTables,
      (i) => CmapData.fromByteData(
        byteData,
        entry.offset + header.encodingRecords[i].offset!,
      ),
    ).whereType<CmapData>().toList();

    return CharacterToGlyphTable(entry, header, data);
  }

  factory CharacterToGlyphTable.create(List<GenericGlyph> fullGlyphList) {
    final charCodeList = fullGlyphList
        .map((e) => e.metadata.charCode)
        .skip(1) // skipping .notdef
        .whereType<int>()
        .toList();

    final segmentList = generateSegments(charCodeList);

    // Format 4 table must end with 0xFFFF char code
    final segmentListFormat4 = [
      ...segmentList,
      CmapSegment(0xFFFF, 0xFFFF, 1),
    ];

    final subtableByFormat = {
      for (final format in _kDefaultEncodingRecordFormatList.toSet())
        format: CmapData.create(
          format == kCmapFormat4 ? segmentListFormat4 : segmentList,
          format,
        ),
    };

    final subtables = [
      for (final format in _kDefaultEncodingRecordFormatList)
        if (subtableByFormat[format] != null) subtableByFormat[format]!,
    ];

    return CharacterToGlyphTable(
      null,
      CharacterToGlyphTableHeader(
        0,
        subtables.length,
        _defaultEncodingRecords(),
      ),
      subtables,
    );
  }

  final CharacterToGlyphTableHeader header;
  final List<CmapData> data;

  @override
  int get size => header.size + data.fold<int>(0, (p, d) => p + d.size);

  @override
  void encodeToBinary(ByteData byteData) {
    var subtableIndex = 0;
    var offset = header.size;

    for (final subtable in data) {
      subtable.encodeToBinary(byteData.sublistView(offset, subtable.size));
      header.encodingRecords[subtableIndex++].offset = offset;
      offset += subtable.size;
    }

    header.encodeToBinary(byteData.sublistView(0, header.size));
  }
}
