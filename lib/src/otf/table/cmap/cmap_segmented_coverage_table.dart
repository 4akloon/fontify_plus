import 'dart:typed_data';

import '../../../utils/otf.dart';
import 'cmap_data.dart';
import 'cmap_format.dart';
import 'cmap_segment.dart';
import 'sequential_map_group.dart';

/// Format 12: runs of consecutive codes, with 32-bit char codes.
///
/// The same shape as format 4 without the BMP ceiling, which is why icon sets
/// mapped into the private use area beyond U+FFFF need it.
class CmapSegmentedCoverageTable extends CmapData {
  CmapSegmentedCoverageTable(
    super.format, {
    required this.reserved,
    required this.length,
    required this.language,
    required this.numGroups,
    required this.groups,
  });

  factory CmapSegmentedCoverageTable.fromByteData(
    ByteData byteData,
    int offset,
  ) {
    final numGroups = byteData.getUint32(offset + 12);

    return CmapSegmentedCoverageTable(
      byteData.getUint16(offset),
      reserved: byteData.getUint16(offset + 2),
      length: byteData.getUint32(offset + 4),
      language: byteData.getUint32(offset + 8),
      numGroups: numGroups,
      groups: List.generate(
        numGroups,
        (i) => SequentialMapGroup.fromByteData(
          byteData,
          offset + 16 + kSequentialMapGroupSize * i,
        ),
      ),
    );
  }

  factory CmapSegmentedCoverageTable.create(List<CmapSegment> segmentList) {
    final groups = [
      for (final segment in segmentList)
        SequentialMapGroup(
          startCharCode: segment.startCode,
          endCharCode: segment.endCode,
          startGlyphID: segment.startGlyphID,
        ),
    ];

    /// Two 2-byte variables
    /// Three 4-byte variables
    /// SequentialMapGroup (12-byte) array of [numGroups] length
    final length = 16 + groups.length * kSequentialMapGroupSize;

    return CmapSegmentedCoverageTable(
      kCmapFormat12,
      reserved: 0,
      length: length,
      language: 0, // Roman language
      numGroups: groups.length,
      groups: groups,
    );
  }

  final int reserved;
  final int length;
  final int language;
  final int numGroups;
  final List<SequentialMapGroup> groups;

  @override
  int get size => length;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, format)
      ..setUint16(2, reserved)
      ..setUint32(4, length)
      ..setUint32(8, language)
      ..setUint32(12, numGroups);

    var offset = 16;

    for (final group in groups) {
      group.encodeToBinary(byteData.sublistView(offset, group.size));
      offset += group.size;
    }
  }
}
