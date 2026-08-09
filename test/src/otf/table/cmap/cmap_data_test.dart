import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/cmap/cmap_byte_encoding_table.dart';
import 'package:fontify_plus/src/otf/table/cmap/cmap_data.dart';
import 'package:fontify_plus/src/otf/table/cmap/cmap_format.dart';
import 'package:fontify_plus/src/otf/table/cmap/cmap_segment.dart';
import 'package:fontify_plus/src/otf/table/cmap/cmap_segment_mapping_table.dart';
import 'package:fontify_plus/src/otf/table/cmap/cmap_segmented_coverage_table.dart';
import 'package:test/test.dart';

void main() {
  group('CmapData.create', () {
    final segments = [CmapSegment(10, 20, 1)];

    test('dispatches format 0 to CmapByteEncodingTable', () {
      expect(
        CmapData.create(segments, kCmapFormat0),
        isA<CmapByteEncodingTable>(),
      );
    });

    test('dispatches format 4 to CmapSegmentMappingToDeltaValuesTable', () {
      expect(
        CmapData.create(segments, kCmapFormat4),
        isA<CmapSegmentMappingToDeltaValuesTable>(),
      );
    });

    test('dispatches format 12 to CmapSegmentedCoverageTable', () {
      expect(
        CmapData.create(segments, kCmapFormat12),
        isA<CmapSegmentedCoverageTable>(),
      );
    });

    test('returns null for an unsupported format', () {
      expect(CmapData.create(segments, 99), isNull);
    });
  });

  group('CmapData.fromByteData', () {
    test('reads the format from the first two bytes and dispatches', () {
      // A format-0 table needs the full 262-byte payload; a zero-filled
      // buffer of that size is a legal (if degenerate) table.
      final bytes = ByteData(262)..setUint16(0, kCmapFormat0);

      expect(CmapData.fromByteData(bytes, 0), isA<CmapByteEncodingTable>());
    });

    test('returns null for an unsupported format', () {
      final bytes = ByteData(2)..setUint16(0, 99);

      expect(CmapData.fromByteData(bytes, 0), isNull);
    });
  });
}
