import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/lookup/lookup_list_table.dart';
import 'package:test/test.dart';

void main() {
  group('LookupListTable.create', () {
    test('declares a single empty ligature lookup', () {
      final table = LookupListTable.create();

      expect(table.lookupCount, 1);
      expect(table.lookupTables.single.lookupType, 4);
    });
  });

  group('LookupListTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final table = LookupListTable.create();
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = LookupListTable.fromByteData(bytes, 0);

      expect(decoded.lookupCount, 1);
      expect(decoded.lookupTables.single.lookupType, 4);
    });
  });
}
