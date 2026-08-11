import 'dart:typed_data';

import 'package:fontify_plus/src/common/glyph/generic_glyph_metrics.dart';
import 'package:fontify_plus/src/otf/table/hhea.dart';
import 'package:fontify_plus/src/otf/table/hmtx.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

void main() {
  group('LongHorMetric.createForGlyph', () {
    test('gives an empty glyph one third of an em, at zero lsb', () {
      final metric = LongHorMetric.createForGlyph(
        GenericGlyphMetrics.empty(),
        999,
      );

      expect(metric.advanceWidth, 999 ~/ 3);
      expect(metric.lsb, 0);
    });

    test('advances a non-empty glyph by its own width', () {
      final metric = LongHorMetric.createForGlyph(
        GenericGlyphMetrics(xMin: 0, xMax: 700, yMin: 0, yMax: 800),
        1000,
      );

      expect(metric.advanceWidth, 700);
    });
  });

  group('LongHorMetric.getRsb', () {
    test('is advanceWidth minus lsb minus glyph width', () {
      final metric = LongHorMetric(700, 10);

      expect(metric.getRsb(710, 10), 700 - (10 + (710 - 10)));
    });
  });

  group('LongHorMetric round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final metric = LongHorMetric(700, -5);
      final bytes = ByteData(metric.size);

      metric.encodeToBinary(bytes);
      final decoded = LongHorMetric.fromByteData(bytes, 0);

      expect(decoded.advanceWidth, 700);
      expect(decoded.lsb, -5);
    });
  });

  group('HorizontalMetricsTable.create', () {
    test('produces one metric per glyph and no left side bearings', () {
      final table = HorizontalMetricsTable.create(
        [
          GenericGlyphMetrics.empty(),
          GenericGlyphMetrics(xMin: 0, xMax: 700, yMin: 0, yMax: 800),
        ],
        1000,
      );

      expect(table.hMetrics, hasLength(2));
      expect(table.leftSideBearings, isEmpty);
    });

    test('advanceWidthMax is the largest advance width', () {
      final table = HorizontalMetricsTable.create(
        [
          GenericGlyphMetrics(xMin: 0, xMax: 100, yMin: 0, yMax: 100),
          GenericGlyphMetrics(xMin: 0, xMax: 700, yMin: 0, yMax: 800),
        ],
        1000,
      );

      expect(table.advanceWidthMax, 700);
    });

    test('minLeftSideBearing is 0 for glyphs created with a zero lsb', () {
      final table = HorizontalMetricsTable.create(
        [GenericGlyphMetrics(xMin: 0, xMax: 700, yMin: 0, yMax: 800)],
        1000,
      );

      expect(table.minLeftSideBearing, 0);
    });

    test(
      'getMinRightSideBearing and getMaxExtent read against the given metrics',
      () {
        final metricsList = [
          GenericGlyphMetrics(xMin: 0, xMax: 700, yMin: 0, yMax: 800),
        ];
        final table = HorizontalMetricsTable.create(metricsList, 1000);

        expect(table.getMinRightSideBearing(metricsList), 0);
        expect(table.getMaxExtent(metricsList), 700);
      },
    );
  });

  group('HorizontalMetricsTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final metricsList = [
        GenericGlyphMetrics.empty(),
        GenericGlyphMetrics(xMin: 0, xMax: 700, yMin: 0, yMax: 800),
      ];
      final table = HorizontalMetricsTable.create(metricsList, 1000);
      final hhea = HorizontalHeaderTable.create(
        metricsList,
        table,
        ascender: 800,
        descender: -200,
      );
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      final decoded = HorizontalMetricsTable.fromByteData(
        bytes,
        TableRecordEntry(
          'hmtx',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
        hhea,
        metricsList.length,
      );

      expect(
        decoded.hMetrics.map((m) => m.advanceWidth),
        table.hMetrics.map((m) => m.advanceWidth),
      );
    });
  });
}
