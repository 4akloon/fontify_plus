import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/all.dart';
import 'package:test/test.dart';

void main() {
  group('CFF2TableHeader.create', () {
    test('declares version 2.0 with a 5-byte fixed header', () {
      final header = CFF2TableHeader.create();

      expect(header.majorVersion, 2);
      expect(header.minorVersion, 0);
      expect(header.headerSize, 5);
      expect(header.topDictLength, isNull);
    });

    test('size is fixed at 5 bytes', () {
      final header = CFF2TableHeader.create();

      expect(header.size, 5);
    });
  });

  group('CFF2TableHeader round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final header = CFF2TableHeader.create()..topDictLength = 12;
      final bytes = ByteData(header.size);

      header.encodeToBinary(bytes);
      final decoded = CFF2TableHeader.fromByteData(bytes);

      expect(decoded.majorVersion, 2);
      expect(decoded.minorVersion, 0);
      expect(decoded.headerSize, 5);
      expect(decoded.topDictLength, 12);
    });
  });
}
