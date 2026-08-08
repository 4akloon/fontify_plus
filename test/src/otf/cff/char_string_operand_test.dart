import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/char_string_operand.dart';
import 'package:test/test.dart';

void main() {
  group('CharStringOperand', () {
    test('an integer value behaves like the base CFFOperand', () {
      final operand = CharStringOperand(42);

      expect(operand.size, 1);
    });

    test('a double value uses the 16.16 fixed-point form', () {
      final operand = CharStringOperand(1.5);

      expect(operand.size, 5);
    });

    test('encodes a double with the 255 marker', () {
      final operand = CharStringOperand(1.5);
      final bytes = ByteData(operand.size);

      operand.encodeToBinary(bytes);

      expect(bytes.getUint8(0), 255);
    });

    test('decodes a one-byte integer through the shared CFFOperand path', () {
      final bytes = ByteData(1)..setUint8(0, 139);

      expect(CharStringOperand.fromByteData(bytes, 1, 139).value, 0);
    });

    test('decodes the 255 marker as a fixed-point number', () {
      final bytes = ByteData(4)..setUint32(0, 3 * 0x10000);

      expect(CharStringOperand.fromByteData(bytes, 0, 255).value, 3.0);
    });
  });
}
