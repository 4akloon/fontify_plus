import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/glyph/flag.dart';
import 'package:test/test.dart';

void main() {
  group('SimpleGlyphFlag.fromIntValue', () {
    test('decodes every bit independently', () {
      final flag = SimpleGlyphFlag.fromIntValue(0xFF & ~0x08); // all but repeat

      expect(flag.onCurvePoint, isTrue);
      expect(flag.xShortVector, isTrue);
      expect(flag.yShortVector, isTrue);
      expect(flag.xIsSameOrPositive, isTrue);
      expect(flag.yIsSameOrPositive, isTrue);
      expect(flag.overlapSimple, isTrue);
      expect(flag.reserved, isTrue);
      expect(flag.isRepeating, isFalse);
    });

    test('is not repeating when no repeat count is given', () {
      final flag = SimpleGlyphFlag.fromIntValue(0x00);

      expect(flag.isRepeating, isFalse);
      expect(flag.repeatTimes, 0);
    });

    test('carries the given repeat count', () {
      final flag = SimpleGlyphFlag.fromIntValue(0x00, 5);

      expect(flag.isRepeating, isTrue);
      expect(flag.repeatTimes, 5);
    });
  });

  group('SimpleGlyphFlag.fromByteData', () {
    test('reads a single byte when the repeat bit is unset', () {
      final bytes = ByteData(1)..setUint8(0, 0x01); // onCurvePoint only

      final flag = SimpleGlyphFlag.fromByteData(bytes, 0);

      expect(flag.onCurvePoint, isTrue);
      expect(flag.isRepeating, isFalse);
    });

    test(
      'reads a second byte as the repeat count when the repeat bit is set',
      () {
        final bytes = ByteData(2)
          ..setUint8(0, 0x01 | 0x08)
          ..setUint8(1, 7);

        final flag = SimpleGlyphFlag.fromByteData(bytes, 0);

        expect(flag.repeatTimes, 7);
      },
    );
  });

  group('SimpleGlyphFlag.createForPoint', () {
    test('marks a short positive delta as short and same-or-positive', () {
      final flag = SimpleGlyphFlag.createForPoint(10, 20, true);

      expect(flag.xShortVector, isTrue);
      expect(flag.xIsSameOrPositive, isTrue);
      expect(flag.yShortVector, isTrue);
      expect(flag.yIsSameOrPositive, isTrue);
    });

    test('marks a short negative delta as short but not same-or-positive', () {
      final flag = SimpleGlyphFlag.createForPoint(-10, -20, false);

      expect(flag.xShortVector, isTrue);
      expect(flag.xIsSameOrPositive, isFalse);
      expect(flag.yShortVector, isTrue);
      expect(flag.yIsSameOrPositive, isFalse);
    });

    test('marks a delta past 0xFF as not short', () {
      final flag = SimpleGlyphFlag.createForPoint(1000, -1000, true);

      expect(flag.xShortVector, isFalse);
      expect(flag.xIsSameOrPositive, isFalse);
      expect(flag.yShortVector, isFalse);
      expect(flag.yIsSameOrPositive, isFalse);
    });

    test('carries the given onCurvePoint through', () {
      expect(SimpleGlyphFlag.createForPoint(0, 0, true).onCurvePoint, isTrue);
      expect(SimpleGlyphFlag.createForPoint(0, 0, false).onCurvePoint, isFalse);
    });
  });

  group('SimpleGlyphFlag.hasSameBits', () {
    test('is true for identical flags regardless of repeat count', () {
      final a = SimpleGlyphFlag.createForPoint(10, 10, true);
      final b = a.repeated(4);

      expect(a.hasSameBits(b), isTrue);
    });

    test('is false when any non-repeat bit differs', () {
      final a = SimpleGlyphFlag.createForPoint(10, 10, true);
      final b = SimpleGlyphFlag.createForPoint(10, 10, false);

      expect(a.hasSameBits(b), isFalse);
    });
  });

  group('SimpleGlyphFlag.repeated', () {
    test('keeps every other field but sets the repeat count', () {
      final flag = SimpleGlyphFlag.createForPoint(10, -300, true).repeated(3);

      expect(flag.repeatTimes, 3);
      expect(flag.isRepeating, isTrue);
      expect(flag.xShortVector, isTrue);
      expect(flag.yShortVector, isFalse);
      expect(flag.onCurvePoint, isTrue);
    });
  });

  group('SimpleGlyphFlag size and encoding', () {
    test('size is 1 byte when not repeating', () {
      final flag = SimpleGlyphFlag.createForPoint(0, 0, true);

      expect(flag.size, 1);
    });

    test('size is 2 bytes when repeating', () {
      final flag = SimpleGlyphFlag.createForPoint(0, 0, true).repeated(2);

      expect(flag.size, 2);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      final flag = SimpleGlyphFlag.createForPoint(-10, 300, false).repeated(6);
      final bytes = ByteData(flag.size);

      flag.encodeToBinary(bytes);
      final decoded = SimpleGlyphFlag.fromByteData(bytes, 0);

      expect(decoded.xShortVector, isTrue);
      expect(decoded.xIsSameOrPositive, isFalse);
      expect(decoded.yShortVector, isFalse);
      expect(decoded.onCurvePoint, isFalse);
      expect(decoded.repeatTimes, 6);
    });
  });
}
