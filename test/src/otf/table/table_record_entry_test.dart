import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

void main() {
  group('TableRecordEntry', () {
    test('size is fixed at 16 bytes', () {
      final entry = TableRecordEntry('glyf', checkSum: 0, offset: 0, length: 0);

      expect(entry.size, 16);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final entry = TableRecordEntry(
        'glyf',
        checkSum: 123456,
        offset: 40,
        length: 200,
      );
      final bytes = ByteData(entry.size);

      entry.encodeToBinary(bytes);
      final decoded = TableRecordEntry.fromByteData(bytes, 0);

      expect(decoded.tag, 'glyf');
      expect(decoded.checkSum, 123456);
      expect(decoded.offset, 40);
      expect(decoded.length, 200);
    });
  });
}
