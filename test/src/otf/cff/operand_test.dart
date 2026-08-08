import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/operand.dart';
import 'package:fontify_plus/src/utils/exception.dart';
import 'package:test/test.dart';

ByteData encode(CFFOperand operand) {
  final bytes = ByteData(operand.size);
  operand.encodeToBinary(bytes);

  return bytes;
}

CFFOperand decode(ByteData bytes, [int offset = 1]) =>
    CFFOperand.fromByteData(bytes, offset, bytes.getUint8(0));

/// Encodes [value] and decodes it straight back.
num roundTrip(num value) {
  final operand = CFFOperand.fromValue(value);
  final bytes = encode(operand);

  return decode(bytes).value!;
}

void main() {
  group('integer size boundaries', () {
    test('a single byte covers -107..107', () {
      expect(CFFOperand.fromValue(107).size, 1);
      expect(CFFOperand.fromValue(-107).size, 1);
    });

    test('two bytes cover 108..1131 and -1131..-108', () {
      expect(CFFOperand.fromValue(108).size, 2);
      expect(CFFOperand.fromValue(1131).size, 2);
      expect(CFFOperand.fromValue(-108).size, 2);
      expect(CFFOperand.fromValue(-1131).size, 2);
    });

    test('three bytes cover the rest of a 16-bit range', () {
      expect(CFFOperand.fromValue(1132).size, 3);
      expect(CFFOperand.fromValue(32767).size, 3);
      expect(CFFOperand.fromValue(-1132).size, 3);
      expect(CFFOperand.fromValue(-32768).size, 3);
    });

    test('five bytes cover anything wider than 16 bits', () {
      expect(CFFOperand.fromValue(32768).size, 5);
      expect(CFFOperand.fromValue(-32769).size, 5);
    });
  });

  group('integer round-trips', () {
    for (final value in [
      0,
      1,
      -1,
      107,
      -107,
      108,
      -108,
      1131,
      -1131,
      1132,
      -1132,
      32767,
      -32768,
      32768,
      -32769,
      1 << 30,
      -(1 << 30)
    ]) {
      test('round-trips $value', () {
        expect(roundTrip(value), value);
      });
    }
  });

  group('real number values', () {
    test('size defers to realNumberSize', () {
      final operand = CFFOperand.fromValue(1.5);

      expect(operand.size, greaterThan(0));
    });

    test('round-trips through binary', () {
      expect(roundTrip(1.5), 1.5);
    });

    test('is written with the real-number marker byte', () {
      final bytes = encode(CFFOperand.fromValue(1.5));

      expect(bytes.getUint8(0), 30);
    });
  });

  group('CFFOperand.fromByteData', () {
    test('decodes a one-byte value from b0 alone', () {
      // b0 in [32, 246] encodes -107..107 as b0 - 139.
      final bytes = ByteData(1)..setUint8(0, 139);

      expect(CFFOperand.fromByteData(bytes, 1, 139).value, 0);
    });

    test('decodes a three-byte value (marker 28)', () {
      final bytes = ByteData(3)
        ..setUint8(0, 28)
        ..setUint16(1, 1000);

      expect(decode(bytes).value, 1000);
    });

    test('decodes a five-byte value (marker 29)', () {
      final bytes = ByteData(5)
        ..setUint8(0, 29)
        ..setUint32(1, 100000);

      expect(decode(bytes).value, 100000);
    });

    test('throws for an unrecognised leading byte', () {
      final bytes = ByteData(1)..setUint8(0, 255);

      expect(
        () => CFFOperand.fromByteData(bytes, 1, 255),
        throwsA(isA<TableDataFormatException>()),
      );
    });
  });

  group('CFFOperand construction', () {
    test('the size given at construction is used as-is', () {
      expect(CFFOperand(5, 99).size, 99);
    });

    test('accessing size on a null-valued operand with no fixed size throws',
        () {
      expect(() => CFFOperand(null, null).size, throwsStateError);
    });

    test('encoding a null-valued operand throws', () {
      final operand = CFFOperand(null, 1);

      expect(
        () => operand.encodeToBinary(ByteData(1)),
        throwsStateError,
      );
    });

    test('toString reports the value', () {
      expect(CFFOperand.fromValue(42).toString(), '42');
    });
  });
}
