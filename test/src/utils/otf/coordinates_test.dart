import 'package:fontify_plus/src/utils/otf/coordinates.dart';
import 'package:test/test.dart';

void main() {
  group('checkBitMask', () {
    test('is true when every bit in the mask is set', () {
      expect(checkBitMask(0xFF, 0x0F), isTrue);
    });

    test('is false when any bit in the mask is clear', () {
      expect(checkBitMask(0xF0, 0x0F), isFalse);
    });

    test('is true for a zero mask', () {
      expect(checkBitMask(0, 0), isTrue);
    });
  });

  group('isShortInteger', () {
    test('is true within [-255, 255]', () {
      expect(isShortInteger(-255), isTrue);
      expect(isShortInteger(0), isTrue);
      expect(isShortInteger(255), isTrue);
    });

    test('is false just outside the range', () {
      expect(isShortInteger(256), isFalse);
      expect(isShortInteger(-256), isFalse);
    });
  });

  group('absToRelCoordinates / relToAbsCoordinates', () {
    test('round-trip a coordinate list', () {
      final absolute = [10, 15, 12, 20];

      expect(relToAbsCoordinates(absToRelCoordinates(absolute)), absolute);
    });

    test('the first relative value equals the first absolute value', () {
      expect(absToRelCoordinates([10, 15, 12]).first, 10);
    });

    test('handles a decreasing sequence with negative deltas', () {
      expect(absToRelCoordinates([10, 5, 0]), [10, -5, -5]);
    });

    test('returns nothing for an empty list', () {
      expect(absToRelCoordinates([]), isEmpty);
      expect(relToAbsCoordinates([]), isEmpty);
    });

    test('relToAbsCoordinates accumulates from zero', () {
      expect(relToAbsCoordinates([5, -2, 3]), [5, 3, 6]);
    });
  });
}
