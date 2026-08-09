import 'dart:typed_data';

import 'package:fontify_plus/src/utils/pascal_string.dart';
import 'package:test/test.dart';

void main() {
  group('PascalString.fromString', () {
    test('length matches the string', () {
      final pascal = PascalString.fromString('hello');

      expect(pascal.string, 'hello');
      expect(pascal.length, 5);
    });

    test('size is the string length plus the length byte', () {
      expect(PascalString.fromString('hello').size, 6);
    });

    test('toString returns the wrapped string', () {
      expect(PascalString.fromString('hello').toString(), 'hello');
    });

    test('handles the empty string', () {
      final pascal = PascalString.fromString('');

      expect(pascal.length, 0);
      expect(pascal.size, 1);
    });
  });

  group('encodeToBinary / fromByteData', () {
    test('round-trips a string through binary', () {
      final pascal = PascalString.fromString('CFF');
      final bytes = ByteData(pascal.size);

      pascal.encodeToBinary(bytes);
      final decoded = PascalString.fromByteData(bytes, 0);

      expect(decoded.string, 'CFF');
      expect(decoded.length, 3);
    });

    test('writes the length as the first byte', () {
      final pascal = PascalString.fromString('AB');
      final bytes = ByteData(pascal.size);

      pascal.encodeToBinary(bytes);

      expect(bytes.getUint8(0), 2);
      expect(bytes.getUint8(1), 'A'.codeUnitAt(0));
      expect(bytes.getUint8(2), 'B'.codeUnitAt(0));
    });

    test('reads starting at the given offset', () {
      final bytes = ByteData(10);
      final pascal = PascalString.fromString('hi');
      pascal.encodeToBinary(bytes.buffer.asByteData(4, pascal.size));

      final decoded = PascalString.fromByteData(bytes, 4);

      expect(decoded.string, 'hi');
    });
  });
}
