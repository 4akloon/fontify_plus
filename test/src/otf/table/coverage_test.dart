import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/coverage.dart';
import 'package:test/test.dart';

void main() {
  group('kDefaultCoverageTable', () {
    test('is an empty format-1 coverage table', () {
      expect(kDefaultCoverageTable.coverageFormat, 1);
      expect(kDefaultCoverageTable.glyphCount, 0);
      expect(kDefaultCoverageTable.glyphArray, isEmpty);
    });
  });

  group('CoverageTableFormat1', () {
    test('size is 4 bytes plus 2 per covered glyph', () {
      const table = CoverageTableFormat1(
        coverageFormat: 1,
        glyphCount: 2,
        glyphArray: [3, 4],
      );

      expect(table.size, 8);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      const table = CoverageTableFormat1(
        coverageFormat: 1,
        glyphCount: 2,
        glyphArray: [3, 4],
      );
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = CoverageTableFormat1.fromByteData(bytes, 0);

      expect(decoded.glyphCount, 2);
      expect(decoded.glyphArray, [3, 4]);
    });
  });

  group('CoverageTable.fromByteData', () {
    test('dispatches format 1 to CoverageTableFormat1', () {
      const table = CoverageTableFormat1(
        coverageFormat: 1,
        glyphCount: 1,
        glyphArray: [7],
      );
      final bytes = ByteData(table.size);
      table.encodeToBinary(bytes);

      final decoded = CoverageTable.fromByteData(bytes, 0);

      expect(decoded, isA<CoverageTableFormat1>());
    });

    test('returns null for an unsupported format', () {
      final bytes = ByteData(2)..setUint16(0, 99);

      expect(CoverageTable.fromByteData(bytes, 0), isNull);
    });
  });
}
