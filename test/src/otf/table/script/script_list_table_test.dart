import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/script/script_list_table.dart';
import 'package:test/test.dart';

void main() {
  group('ScriptListTable.create', () {
    test('declares the default and Latin scripts', () {
      final table = ScriptListTable.create();

      expect(table.scriptCount, 2);
      expect(
        table.scriptRecords.map((r) => r.scriptTag),
        ['DFLT', 'latn'],
      );
    });
  });

  group('ScriptListTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final table = ScriptListTable.create();
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);
      final decoded = ScriptListTable.fromByteData(bytes, 0);

      expect(decoded.scriptCount, 2);
      expect(
        decoded.scriptRecords.map((r) => r.scriptTag),
        ['DFLT', 'latn'],
      );
      expect(decoded.scriptTables, hasLength(2));
    });
  });
}
