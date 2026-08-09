import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/all.dart';
import 'package:test/test.dart';

void main() {
  group('CFF1TableHeader.create', () {
    test('declares version 1.0 with a 4-byte fixed header', () {
      final header = CFF1TableHeader.create();

      expect(header.majorVersion, 1);
      expect(header.minorVersion, 0);
      expect(header.headerSize, 4);
      expect(header.offSize, isNull);
    });

    test('size is fixed at 4 bytes', () {
      final header = CFF1TableHeader.create();

      expect(header.size, 4);
    });
  });

  group('CFF1TableHeader round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final header = CFF1TableHeader.create()..offSize = 2;
      final bytes = ByteData(header.size);

      header.encodeToBinary(bytes);
      final decoded = CFF1TableHeader.fromByteData(bytes);

      expect(decoded.majorVersion, 1);
      expect(decoded.minorVersion, 0);
      expect(decoded.headerSize, 4);
      expect(decoded.offSize, 2);
    });
  });
}
