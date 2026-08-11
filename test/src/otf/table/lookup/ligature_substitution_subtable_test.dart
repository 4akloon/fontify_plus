import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/coverage.dart';
import 'package:fontify_plus/src/otf/table/lookup/ligature_substitution_subtable.dart';
import 'package:test/test.dart';

void main() {
  group('LigatureSubstitutionSubtable', () {
    test('maxContext is always 0 (ligature sets are not yet generated)', () {
      const subtable = LigatureSubstitutionSubtable(
        substFormat: 1,
        coverageOffset: 6,
        ligatureSetCount: 0,
        ligatureSetOffsets: [],
        coverageTable: null,
      );

      expect(subtable.maxContext, 0);
    });

    test('size is 6 bytes plus 2 per ligature set plus the coverage table', () {
      const subtable = LigatureSubstitutionSubtable(
        substFormat: 1,
        coverageOffset: 6,
        ligatureSetCount: 1,
        ligatureSetOffsets: [8],
        coverageTable: kDefaultCoverageTable,
      );

      expect(subtable.size, 6 + 2 * 1 + kDefaultCoverageTable.size);
    });
  });

  group('LigatureSubstitutionSubtable round trip', () {
    test(
      'round-trips an empty ligature set through encodeToBinary and fromByteData',
      () {
        const subtable = LigatureSubstitutionSubtable(
          substFormat: 1,
          coverageOffset: 6,
          ligatureSetCount: 0,
          ligatureSetOffsets: [],
          coverageTable: kDefaultCoverageTable,
        );
        final bytes = ByteData(subtable.size);

        subtable.encodeToBinary(bytes);
        final decoded = LigatureSubstitutionSubtable.fromByteData(bytes, 0);

        expect(decoded.substFormat, 1);
        expect(decoded.ligatureSetCount, 0);
        expect(decoded.coverageTable, isA<CoverageTableFormat1>());
      },
    );
  });
}
