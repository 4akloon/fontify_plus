import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/name/name_record.dart';
import 'package:test/test.dart';

void main() {
  group('NameRecord.template', () {
    test('leaves the string-specific fields as placeholders', () {
      const record = NameRecord.template(3, 1, 0x0409);

      expect(record.nameID, -1);
      expect(record.length, -1);
      expect(record.offset, -1);
    });

    test('keeps the platform fields given to it', () {
      const record = NameRecord.template(3, 1, 0x0409);

      expect(record.platformID, 3);
      expect(record.encodingID, 1);
      expect(record.languageID, 0x0409);
    });
  });

  group('NameRecord.copyWith', () {
    test('fills the template\'s placeholders in for one string', () {
      const template = NameRecord.template(3, 1, 0x0409);
      final record = template.copyWith(nameID: 1, length: 10, offset: 0);

      expect(record.nameID, 1);
      expect(record.length, 10);
      expect(record.offset, 0);
    });

    test('keeps the platform fields from the template unless overridden', () {
      const template = NameRecord.template(3, 1, 0x0409);
      final record = template.copyWith(nameID: 1, length: 10, offset: 0);

      expect(record.platformID, 3);
      expect(record.encodingID, 1);
      expect(record.languageID, 0x0409);
    });

    test('does not mutate the original', () {
      const template = NameRecord.template(3, 1, 0x0409);
      template.copyWith(nameID: 5);

      expect(template.nameID, -1);
    });
  });

  group('NameRecord round trip', () {
    test('size is fixed at 12 bytes', () {
      final record = NameRecord(3, 1, 0x0409, 1, 10, 0);

      expect(record.size, 12);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final record = NameRecord(3, 1, 0x0409, 4, 20, 100);
      final bytes = ByteData(record.size);

      record.encodeToBinary(bytes);
      final decoded = NameRecord.fromByteData(bytes, 0);

      expect(decoded.platformID, 3);
      expect(decoded.encodingID, 1);
      expect(decoded.languageID, 0x0409);
      expect(decoded.nameID, 4);
      expect(decoded.length, 20);
      expect(decoded.offset, 100);
    });
  });
}
