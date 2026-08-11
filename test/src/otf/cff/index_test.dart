import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/index.dart';
import 'package:fontify_plus/src/utils/exception.dart';
import 'package:test/test.dart';

ByteData encode(CFFIndex index) {
  final bytes = ByteData(index.size);
  index.encodeToBinary(bytes);

  return bytes;
}

void main() {
  group('CFFIndex.empty', () {
    test('has a count of zero', () {
      expect(CFFIndex.empty(true).count, 0);
      expect(CFFIndex.empty(true).isEmpty, isTrue);
    });

    test('size is just the count field, for both CFF1 and CFF2', () {
      expect(CFFIndex.empty(true).size, 2);
      expect(CFFIndex.empty(false).size, 4);
    });

    test('encodes as just the zero count, with no offSize or offsets', () {
      final bytes = encode(CFFIndex.empty(true));

      expect(bytes.lengthInBytes, 2);
      expect(bytes.getUint16(0), 0);
    });
  });

  group('CFFIndex.countSizeFor', () {
    test('CFF1 uses a 16-bit count', () {
      expect(CFFIndex.countSizeFor(true), 2);
    });

    test('CFF2 widened the count to 32 bits', () {
      expect(CFFIndex.countSizeFor(false), 4);
    });
  });

  group('CFFIndex construction and size', () {
    test('size accounts for the offset array and the offSize byte', () {
      // 2 elements -> 3 offsets, each offSize=1 byte, plus 1 offSize byte.
      final index = CFFIndex(
        count: 2,
        offSize: 1,
        offsetList: [1, 2, 3],
        isCFF1: true,
      );

      expect(index.size, CFFIndex.countSizeFor(true) + 1 + 3);
    });

    test('encodeToBinary throws for an offSize outside 1..4', () {
      final index = CFFIndex(
        count: 1,
        offSize: 5,
        offsetList: [1, 2],
        isCFF1: true,
      );

      expect(() => encode(index), throwsA(isA<TableDataFormatException>()));
    });
  });

  group('CFFIndex.fromByteData / encodeToBinary round trip', () {
    test('round-trips a non-empty CFF1 index', () {
      final original = CFFIndex(
        count: 2,
        offSize: 1,
        offsetList: [1, 5, 10],
        isCFF1: true,
      );
      final bytes = encode(original);

      final decoded = CFFIndex.fromByteData(bytes, true);

      expect(decoded.count, 2);
      expect(decoded.offSize, 1);
      expect(decoded.offsetList, [1, 5, 10]);
    });

    test('round-trips a non-empty CFF2 index', () {
      final original = CFFIndex(
        count: 2,
        offSize: 1,
        offsetList: [1, 5, 10],
        isCFF1: false,
      );
      final bytes = encode(original);

      final decoded = CFFIndex.fromByteData(bytes, false);

      expect(decoded.offsetList, [1, 5, 10]);
    });

    test('round-trips an empty index', () {
      final bytes = encode(CFFIndex.empty(true));
      final decoded = CFFIndex.fromByteData(bytes, true);

      expect(decoded.isEmpty, isTrue);
    });

    test('round-trips a multi-byte offSize', () {
      // A large offset that needs 2 bytes per entry.
      final original = CFFIndex(
        count: 1,
        offSize: 2,
        offsetList: [1, 1000],
        isCFF1: true,
      );
      final bytes = encode(original);

      final decoded = CFFIndex.fromByteData(bytes, true);

      expect(decoded.offsetList, [1, 1000]);
    });
  });
}
