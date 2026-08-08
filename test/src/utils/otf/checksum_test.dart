import 'dart:typed_data';

import 'package:fontify_plus/src/utils/otf/checksum.dart';
import 'package:test/test.dart';

void main() {
  group('calculateTableChecksum', () {
    test('is the sum of the table\'s 32-bit words', () {
      final bytes = ByteData(8)
        ..setUint32(0, 1)
        ..setUint32(4, 2);

      expect(calculateTableChecksum(bytes), 3);
    });

    test('zero-pads a length that is not a multiple of four', () {
      // 5 bytes: one full word plus a single trailing byte, which pads to a
      // full word with zeroes before summing.
      final bytes = ByteData(5)
        ..setUint32(0, 1)
        ..setUint8(4, 2);

      expect(calculateTableChecksum(bytes), 1 + (2 << 24));
    });

    test('wraps on overflow past 32 bits', () {
      final bytes = ByteData(8)
        ..setUint32(0, 0xFFFFFFFF)
        ..setUint32(4, 2);

      expect(calculateTableChecksum(bytes), 1);
    });

    test('is zero for an all-zero table', () {
      expect(calculateTableChecksum(ByteData(12)), 0);
    });
  });

  group('calculateFontChecksum', () {
    test('is derived from the magic number and the table checksum', () {
      final bytes = ByteData(4)..setUint32(0, 5);

      expect(
        calculateFontChecksum(bytes),
        (0xB1B0AFBA - 5).toUnsigned(32),
      );
    });
  });

  group('getPaddedTableSize', () {
    test('leaves an already-aligned size alone', () {
      expect(getPaddedTableSize(8), 8);
    });

    test('rounds up to the next multiple of four', () {
      expect(getPaddedTableSize(9), 12);
      expect(getPaddedTableSize(10), 12);
      expect(getPaddedTableSize(11), 12);
    });

    test('zero stays zero', () {
      expect(getPaddedTableSize(0), 0);
    });
  });
}
