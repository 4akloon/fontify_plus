import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/name/naming_table.dart';
import 'package:fontify_plus/src/otf/table/name/naming_table_format0.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

void main() {
  group('NamingTable.create', () {
    test('format 0 dispatches to NamingTableFormat0', () {
      expect(
        NamingTable.create('My Icons', null, const Revision(1, 0)),
        isA<NamingTableFormat0>(),
      );
    });

    test('returns null for an unsupported format', () {
      expect(
        NamingTable.create('My Icons', null, const Revision(1, 0), format: 99),
        isNull,
      );
    });
  });

  group('NamingTable.fromByteData', () {
    test('format 0 dispatches to NamingTableFormat0', () {
      final built =
          NamingTableFormat0.create('My Icons', null, const Revision(1, 0));
      final bytes = ByteData(built.size);
      built.encodeToBinary(bytes);

      final decoded = NamingTable.fromByteData(
        bytes,
        TableRecordEntry('name', 0, 0, bytes.lengthInBytes),
      );

      expect(decoded, isA<NamingTableFormat0>());
    });

    test('returns null for an unsupported format', () {
      final bytes = ByteData(6)..setUint16(0, 99);

      expect(
        NamingTable.fromByteData(
          bytes,
          TableRecordEntry('name', 0, 0, bytes.lengthInBytes),
        ),
        isNull,
      );
    });
  });
}
