import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/cmap/cmap_format.dart';
import 'package:fontify_plus/src/otf/table/cmap/cmap_segment.dart';
import 'package:fontify_plus/src/otf/table/cmap/cmap_segmented_coverage_table.dart';
import 'package:test/test.dart';

void main() {
  group('CmapSegmentedCoverageTable.create', () {
    test('declares format 12', () {
      final table = CmapSegmentedCoverageTable.create(
        [CmapSegment(0x10000, 0x10010, 1)],
      );

      expect(table.format, kCmapFormat12);
    });

    test('one group per segment', () {
      final table = CmapSegmentedCoverageTable.create(
        [CmapSegment(1, 2, 1), CmapSegment(10, 20, 2)],
      );

      expect(table.numGroups, 2);
      expect(table.groups, hasLength(2));
    });
  });

  group('CmapSegmentedCoverageTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final table = CmapSegmentedCoverageTable.create(
        [CmapSegment(0x10000, 0x10010, 1)],
      );
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = CmapSegmentedCoverageTable.fromByteData(bytes, 0);

      expect(decoded.numGroups, 1);
      expect(decoded.groups.single.startCharCode, 0x10000);
      expect(decoded.groups.single.endCharCode, 0x10010);
      expect(decoded.groups.single.startGlyphID, 1);
    });
  });
}
