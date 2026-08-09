import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import '../../debugger.dart';
import 'cmap_byte_encoding_table.dart';
import 'cmap_format.dart';
import 'cmap_segment.dart';
import 'cmap_segment_mapping_table.dart';
import 'cmap_segmented_coverage_table.dart';

/// One cmap subtable, in whichever format it declares.
abstract class CmapData implements BinaryCodable {
  CmapData(this.format);

  /// Reads the subtable at [offset], or null when its format is unsupported.
  static CmapData? fromByteData(ByteData byteData, int offset) {
    final format = byteData.getUint16(offset);

    switch (format) {
      case kCmapFormat0:
        return CmapByteEncodingTable.fromByteData(byteData, offset);
      case kCmapFormat4:
        return CmapSegmentMappingToDeltaValuesTable.fromByteData(
          byteData,
          offset,
        );
      case kCmapFormat12:
        return CmapSegmentedCoverageTable.fromByteData(byteData, offset);
    }

    debuggerOTF.debugUnsupportedTableFormat(kCmapTag, format);

    return null;
  }

  /// Builds a subtable of [format] covering [segmentList].
  static CmapData? create(List<CmapSegment> segmentList, int format) {
    switch (format) {
      case kCmapFormat0:
        return CmapByteEncodingTable.create();
      case kCmapFormat4:
        return CmapSegmentMappingToDeltaValuesTable.create(segmentList);
      case kCmapFormat12:
        return CmapSegmentedCoverageTable.create(segmentList);
    }

    debuggerOTF.debugUnsupportedTableFormat(kCmapTag, format);

    return null;
  }

  final int format;
}
