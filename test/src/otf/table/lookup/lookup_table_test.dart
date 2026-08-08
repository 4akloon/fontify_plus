import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/coverage.dart';
import 'package:fontify_plus/src/otf/table/lookup/ligature_substitution_subtable.dart';
import 'package:fontify_plus/src/otf/table/lookup/lookup_table.dart';
import 'package:test/test.dart';

const _kSubtable = LigatureSubstitutionSubtable(
  1,
  6,
  0,
  [],
  kDefaultCoverageTable,
);

void main() {
  group('LookupTable.size', () {
    test('is 6 bytes plus 2 per subtable offset plus the subtables', () {
      const table = LookupTable(4, 0, 1, [8], null, [_kSubtable]);

      expect(table.size, 6 + 2 * 1 + _kSubtable.size);
    });
  });

  group('LookupTable round trip', () {
    test('round-trips a table without a mark-filtering set', () {
      const table = LookupTable(4, 0, 1, [8], null, [_kSubtable]);
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = LookupTable.fromByteData(bytes, 0);

      expect(decoded.lookupType, 4);
      expect(decoded.subTableCount, 1);
      expect(decoded.subtables, hasLength(1));
      expect(decoded.markFilteringSet, isNull);
    });

    test('round-trips a table with a mark-filtering set (flag bit 0x0010)', () {
      const table = LookupTable(4, 0x0010, 1, [8], 3, [_kSubtable]);
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = LookupTable.fromByteData(bytes, 0);

      expect(decoded.markFilteringSet, 3);
    });

    test('drops subtables for an unsupported lookup type', () {
      final bytes = ByteData(6 + 2);

      bytes.setUint16(0, 99);
      bytes.setUint16(4, 1);
      bytes.setUint16(6, 8);

      final decoded = LookupTable.fromByteData(bytes, 0);

      expect(decoded.subtables, isEmpty);
    });
  });
}
