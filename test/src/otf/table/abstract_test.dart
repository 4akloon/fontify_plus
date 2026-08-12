import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/abstract.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

class _FakeTable extends FontTable {
  _FakeTable(super.entry) : super.fromTableRecordEntry();

  @override
  int get size => 0;

  @override
  void encodeToBinary(ByteData byteData) {}
}

void main() {
  group('FontTable.fromTableRecordEntry', () {
    test('carries the given entry through', () {
      const entry = TableRecordEntry('glyf', checkSum: 0, offset: 0, length: 0);
      final table = _FakeTable(entry);

      expect(table.entry, same(entry));
    });

    test('allows a null entry for a table not yet backed by a file', () {
      final table = _FakeTable(null);

      expect(table.entry, isNull);
    });
  });
}
