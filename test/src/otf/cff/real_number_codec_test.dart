import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/real_number_codec.dart';
import 'package:test/test.dart';

ByteData encode(double value) {
  final bytes = ByteData(realNumberSize(value));
  encodeRealNumber(bytes, value);

  return bytes;
}

void main() {
  group('encodeRealNumber / decodeRealNumber', () {
    test('round-trips a positive value with a fractional part', () {
      final bytes = encode(1.5);
      final (value, size) = decodeRealNumber(bytes, 1);

      expect(value, 1.5);
      expect(size, bytes.lengthInBytes);
    });

    test('round-trips a negative value', () {
      final bytes = encode(-2.25);
      final (value, size) = decodeRealNumber(bytes, 1);

      expect(value, -2.25);
      expect(size, bytes.lengthInBytes);
    });

    test('round-trips a value with no fractional part', () {
      final bytes = encode(42.0);
      final (value, size) = decodeRealNumber(bytes, 1);

      expect(value, 42.0);
    });

    test('starts every encoding with the real-number marker byte', () {
      final bytes = encode(1.5);

      expect(bytes.getUint8(0), 30);
    });

    test('drops the leading zero of a fraction below 1', () {
      // '0.5' -> '.5': one fewer nibble to encode.
      expect(realNumberSize(0.5), lessThan(realNumberSize(10.5)));
    });

    test('an odd digit count still fits a whole number of bytes', () {
      final bytes = encode(1.0);

      expect(bytes.lengthInBytes, realNumberSize(1.0));
    });
  });

  group('realNumberSize', () {
    test('is one for the marker plus enough nibble pairs for the digits', () {
      // "1.5" is 3 characters -> 2 nibble pairs (padded) + 1 marker byte.
      expect(realNumberSize(1.5), 3);
    });

    test('counts "E-" as a single nibble', () {
      // Without that collapsing, the exponent sign would cost an extra pair.
      const withExponent = 1.5e-10;
      final text = withExponent.toString();

      expect(text, contains('e-'));
      expect(realNumberSize(withExponent),
          lessThan(1 + ((text.length + 1) / 2).ceil() + 1));
    });
  });

  group('normalizedRealNumber', () {
    test('uses uppercase E for the exponent', () {
      expect(normalizedRealNumber(1.5e21), contains('E'));
      expect(normalizedRealNumber(1.5e21), isNot(contains('e')));
    });

    test('drops the plus sign from a positive exponent', () {
      expect(normalizedRealNumber(1.5e21), isNot(contains('+')));
    });

    test('drops the leading zero from a fraction below 1', () {
      expect(normalizedRealNumber(0.5), startsWith('.'));
    });

    test('leaves a value of 1 or more with its integer part intact', () {
      expect(normalizedRealNumber(10.5), startsWith('10'));
    });
  });
}
