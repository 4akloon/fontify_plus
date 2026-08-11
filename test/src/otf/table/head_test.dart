import 'dart:typed_data';

import 'package:fontify_plus/src/common/glyph/generic_glyph_metrics.dart';
import 'package:fontify_plus/src/otf/table/head.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

List<GenericGlyphMetrics> _metricsList() => [
  GenericGlyphMetrics.empty(),
  GenericGlyphMetrics(xMin: -5, xMax: 700, yMin: -10, yMax: 800),
];

void main() {
  group('HeaderTable.create', () {
    test('computes the font bounding box across every glyph', () {
      final table = HeaderTable.create(
        _metricsList(),
        null,
        const Revision(1, 0),
        1000,
      );

      expect(table.xMin, -5);
      expect(table.yMin, -10);
      expect(table.xMax, 700);
      expect(table.yMax, 800);
    });

    test('carries unitsPerEm and revision through', () {
      final table = HeaderTable.create(
        _metricsList(),
        null,
        const Revision(2, 5),
        2048,
      );

      expect(table.unitsPerEm, 2048);
      expect(table.fontRevision.major, 2);
      expect(table.fontRevision.minor, 5);
    });

    test('uses the short loca format when there is no glyf table', () {
      final table = HeaderTable.create(
        _metricsList(),
        null,
        const Revision(1, 0),
        1000,
      );

      expect(table.indexToLocFormat, 0);
    });

    test('sets created and modified to the same instant', () {
      final table = HeaderTable.create(
        _metricsList(),
        null,
        const Revision(1, 0),
        1000,
      );

      expect(table.created, table.modified);
    });
  });

  group('HeaderTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final table = HeaderTable.create(
        _metricsList(),
        null,
        const Revision(1, 0),
        1000,
      );
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      final decoded = HeaderTable.fromByteData(
        bytes,
        TableRecordEntry(
          'head',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
      );

      expect(decoded.unitsPerEm, 1000);
      expect(decoded.xMin, -5);
      expect(decoded.yMax, 800);
      expect(decoded.fontRevision.major, 1);
      // The wire format only has second precision, so allow for truncation.
      expect(
        decoded.created.difference(table.created).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
    });
  });
}
