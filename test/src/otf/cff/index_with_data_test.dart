import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/index_with_data.dart';
import 'package:test/test.dart';

/// Encodes [indexWithData] the way a real font write does: recalculate
/// offsets, size the buffer, then encode.
ByteData encode(CFFIndexWithData indexWithData) {
  indexWithData.recalculateOffsets();

  final bytes = ByteData(indexWithData.size);
  indexWithData.encodeToBinary(bytes);

  return bytes;
}

void main() {
  group('CFFIndexWithData.create', () {
    test('size is just the count field for no data', () {
      final index = CFFIndexWithData<Uint8List>.create([], true);

      expect(index.size, 2);
    });

    test('accounts for every element\'s bytes', () {
      final index = CFFIndexWithData<Uint8List>.create(
        [
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([4, 5]),
        ],
        true,
      );

      // header + offSize byte + 3 offsets + 5 data bytes.
      expect(index.size, 2 + 1 + 3 * 1 + 5);
    });
  });

  group('CFFIndexWithData round trip', () {
    test('round-trips raw byte elements', () {
      final original = CFFIndexWithData<Uint8List>.create(
        [
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([4, 5]),
        ],
        true,
      );

      final bytes = encode(original);
      final decoded = CFFIndexWithData<Uint8List>.fromByteData(bytes, true);

      expect(decoded.data, [
        [1, 2, 3],
        [4, 5],
      ]);
    });

    test('round-trips an empty element list', () {
      final original = CFFIndexWithData<Uint8List>.create([], true);
      final bytes = encode(original);

      final decoded = CFFIndexWithData<Uint8List>.fromByteData(bytes, true);

      expect(decoded.data, isEmpty);
    });

    test('round-trips through the CFF2 count width', () {
      final original = CFFIndexWithData<Uint8List>.create(
        [
          Uint8List.fromList([9]),
        ],
        false,
      );

      final bytes = encode(original);
      final decoded = CFFIndexWithData<Uint8List>.fromByteData(bytes, false);

      expect(decoded.data.single, [9]);
    });
  });

  group('CFFIndexWithData.recalculateOffsets', () {
    test('picks the smallest offSize that fits the total size', () {
      final index = CFFIndexWithData<Uint8List>.create(
        [
          Uint8List.fromList([1]),
        ],
        true,
      )..recalculateOffsets();

      expect(index.index!.offSize, 1);
    });

    test('grows offSize once the total exceeds a single byte', () {
      final index = CFFIndexWithData<Uint8List>.create(
        [Uint8List(300)],
        true,
      )..recalculateOffsets();

      // The final offset is 301, which needs 2 bytes.
      expect(index.index!.offSize, 2);
    });

    test('an empty list produces an empty CFFIndex', () {
      final index = CFFIndexWithData<Uint8List>.create([], true)
        ..recalculateOffsets();

      expect(index.index!.isEmpty, isTrue);
    });
  });

  group('CFFIndexWithData.size without a prior recalculateOffsets call', () {
    test('computes size correctly even before encoding', () {
      // size must not depend on recalculateOffsets having already run — it
      // recomputes the layout itself.
      final index = CFFIndexWithData<Uint8List>.create(
        [
          Uint8List.fromList([1, 2, 3]),
        ],
        true,
      );

      expect(index.size, greaterThan(0));
    });
  });

  group('CFFIndexWithData.encodeToBinary', () {
    test('throws when asked to encode before offsets are calculated', () {
      final index = CFFIndexWithData<Uint8List>.create(
        [
          Uint8List.fromList([1]),
        ],
        true,
      );

      expect(
        () => index.encodeToBinary(ByteData(index.size)),
        throwsStateError,
      );
    });

    test('an empty index can be encoded once recalculateOffsets has run', () {
      final index = CFFIndexWithData<Uint8List>.create([], true)
        ..recalculateOffsets();

      expect(() => index.encodeToBinary(ByteData(index.size)), returnsNormally);
    });
  });
}
