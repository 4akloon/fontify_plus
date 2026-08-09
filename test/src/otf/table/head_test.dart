import 'dart:typed_data';

import 'package:fontify_plus/src/common/glyph/generic_glyph_metrics.dart';
import 'package:fontify_plus/src/otf/defaults.dart';
import 'package:fontify_plus/src/otf/table/head.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

List<GenericGlyphMetrics> _metricsList() => [
  GenericGlyphMetrics.empty(),
  GenericGlyphMetrics(-5, 700, -10, 800),
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

    test('defaults created/modified to kDefaultFontTimestamp', () {
      final table = HeaderTable.create(
        _metricsList(),
        null,
        const Revision(1, 0),
        1000,
      );

      expect(table.created, kDefaultFontTimestamp);
      expect(table.modified, kDefaultFontTimestamp);
    });

    test('honors explicit created and modified', () {
      final created = DateTime.utc(2019, 5, 1);
      final modified = DateTime.utc(2021, 6, 2);
      final table = HeaderTable.create(
        _metricsList(),
        null,
        const Revision(1, 0),
        1000,
        created: created,
        modified: modified,
      );

      expect(table.created, created);
      expect(table.modified, modified);
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
        TableRecordEntry('head', 0, 0, bytes.lengthInBytes),
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
