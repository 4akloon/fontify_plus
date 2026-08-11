import 'dart:typed_data';

import 'package:fontify_plus/src/common/glyph/generic_glyph_metrics.dart';
import 'package:fontify_plus/src/otf/table/hhea.dart';
import 'package:fontify_plus/src/otf/table/hmtx.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

List<GenericGlyphMetrics> _metricsList() => [
  GenericGlyphMetrics.empty(),
  GenericGlyphMetrics(xMin: 0, xMax: 700, yMin: 0, yMax: 800),
];

void main() {
  group('HorizontalHeaderTable.create', () {
    test('carries the given ascender/descender through', () {
      final hmtx = HorizontalMetricsTable.create(_metricsList(), 1000);
      final table = HorizontalHeaderTable.create(
        _metricsList(),
        hmtx,
        800,
        -200,
      );

      expect(table.ascender, 800);
      expect(table.descender, -200);
    });

    test('numberOfHMetrics equals the glyph count', () {
      final hmtx = HorizontalMetricsTable.create(_metricsList(), 1000);
      final table = HorizontalHeaderTable.create(
        _metricsList(),
        hmtx,
        800,
        -200,
      );

      expect(table.numberOfHMetrics, 2);
    });

    test('reads advanceWidthMax and side-bearing extremes from hmtx', () {
      final hmtx = HorizontalMetricsTable.create(_metricsList(), 1000);
      final table = HorizontalHeaderTable.create(
        _metricsList(),
        hmtx,
        800,
        -200,
      );

      expect(table.advanceWidthMax, hmtx.advanceWidthMax);
      expect(table.minLeftSideBearing, hmtx.minLeftSideBearing);
    });
  });

  group('HorizontalHeaderTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final hmtx = HorizontalMetricsTable.create(_metricsList(), 1000);
      final table = HorizontalHeaderTable.create(
        _metricsList(),
        hmtx,
        800,
        -200,
      );
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      final decoded = HorizontalHeaderTable.fromByteData(
        bytes,
        TableRecordEntry(
          'hhea',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
      );

      expect(decoded.ascender, 800);
      expect(decoded.descender, -200);
      expect(decoded.numberOfHMetrics, 2);
    });
  });
}
