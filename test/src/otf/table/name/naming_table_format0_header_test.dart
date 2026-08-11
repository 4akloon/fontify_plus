import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/name/name_record.dart';
import 'package:fontify_plus/src/otf/table/name/naming_table_format0_header.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

void main() {
  group('NamingTableFormat0Header.create', () {
    test('declares format 0', () {
      final header = NamingTableFormat0Header.create([]);

      expect(header.format, 0);
    });

    test('stringOffset points just past the record list', () {
      final records = [
        NameRecord(
          platformID: 1,
          encodingID: 0,
          languageID: 0,
          nameID: 0,
          length: 5,
          offset: 0,
        ),
      ];
      final header = NamingTableFormat0Header.create(records);

      expect(header.stringOffset, 6 + 12);
    });
  });

  group('NamingTableFormat0Header round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final records = [
        NameRecord(
          platformID: 1,
          encodingID: 0,
          languageID: 0,
          nameID: 1,
          length: 5,
          offset: 0,
        ),
      ];
      final header = NamingTableFormat0Header.create(records);
      final bytes = ByteData(header.size);

      header.encodeToBinary(bytes);

      final decoded = NamingTableFormat0Header.fromByteData(
        bytes,
        TableRecordEntry(
          'name',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
      );

      expect(decoded!.count, 1);
      expect(decoded.nameRecordList.single.nameID, 1);
    });

    test('returns null for an unsupported format', () {
      final bytes = ByteData(6)..setUint16(0, 99);

      final decoded = NamingTableFormat0Header.fromByteData(
        bytes,
        TableRecordEntry(
          'name',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
      );

      expect(decoded, isNull);
    });
  });
}
