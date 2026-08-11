import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/cmap/cmap_format.dart';
import 'package:fontify_plus/src/otf/table/cmap/cmap_segment.dart';
import 'package:fontify_plus/src/otf/table/cmap/cmap_segment_mapping_table.dart';
import 'package:test/test.dart';

void main() {
  group('CmapSegmentMappingToDeltaValuesTable.create', () {
    test('declares format 4', () {
      final table = CmapSegmentMappingToDeltaValuesTable.create(
        [const CmapSegment(startCode: 10, endCode: 20, startGlyphID: 1)],
      );

      expect(table.format, kCmapFormat4);
    });

    test('carries over start/end codes and computed idDelta', () {
      final table = CmapSegmentMappingToDeltaValuesTable.create(
        [const CmapSegment(startCode: 10, endCode: 20, startGlyphID: 1)],
      );

      expect(table.startCode, [10]);
      expect(table.endCode, [20]);
      expect(table.idDelta, [1 - 10]);
    });

    test('segCount matches the number of segments', () {
      final table = CmapSegmentMappingToDeltaValuesTable.create(
        [
          const CmapSegment(startCode: 10, endCode: 20, startGlyphID: 1),
          const CmapSegment(startCode: 30, endCode: 40, startGlyphID: 2),
        ],
      );

      expect(table.segCount, 2);
    });
  });

  group('CmapSegmentMappingToDeltaValuesTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final table = CmapSegmentMappingToDeltaValuesTable.create(
        [
          const CmapSegment(startCode: 10, endCode: 20, startGlyphID: 1),
          const CmapSegment(startCode: 30, endCode: 35, startGlyphID: 12),
        ],
      );
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = CmapSegmentMappingToDeltaValuesTable.fromByteData(
        bytes,
        0,
      );

      expect(decoded.segCount, 2);
      expect(decoded.startCode, [10, 30]);
      expect(decoded.endCode, [20, 35]);
      expect(decoded.idDelta, table.idDelta);
    });

    test('round-trips a negative idDelta', () {
      // startGlyphID < startCode makes idDelta negative — must survive a
      // signed read, not wrap around as unsigned.
      final table = CmapSegmentMappingToDeltaValuesTable.create(
        [const CmapSegment(startCode: 1000, endCode: 1010, startGlyphID: 1)],
      );
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = CmapSegmentMappingToDeltaValuesTable.fromByteData(
        bytes,
        0,
      );

      expect(decoded.idDelta.single, lessThan(0));
      expect(decoded.idDelta.single, table.idDelta.single);
    });
  });
}
