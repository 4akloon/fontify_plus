import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/offset.dart';
import 'package:test/test.dart';

void main() {
  group('OffsetTable.create', () {
    test('marks an OpenType (CFF) font with the OTTO version tag', () {
      final table = OffsetTable.create(9, true);

      expect(table.isOpenType, isTrue);
    });

    test('marks a TrueType font with the 1.0 version tag', () {
      final table = OffsetTable.create(9, false);

      expect(table.isOpenType, isFalse);
    });

    test('computes searchRange/entrySelector/rangeShift from numTables', () {
      // 9 tables: floor(log2(9)) = 3, searchRange = 16 * 2^3 = 128.
      final table = OffsetTable.create(9, false);

      expect(table.entrySelector, 3);
      expect(table.searchRange, 128);
      expect(table.rangeShift, 9 * 16 - 128);
    });
  });

  group('OffsetTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final table = OffsetTable.create(4, true);
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = OffsetTable.fromByteData(bytes);

      expect(decoded.isOpenType, isTrue);
      expect(decoded.numTables, 4);
      expect(decoded.searchRange, table.searchRange);
      expect(decoded.entrySelector, table.entrySelector);
      expect(decoded.rangeShift, table.rangeShift);
    });
  });
}
