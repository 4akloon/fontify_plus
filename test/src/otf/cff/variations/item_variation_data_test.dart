import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/variations/item_variation_data.dart';
import 'package:test/test.dart';

void main() {
  group('ItemVariationData.size', () {
    test('is 6 bytes plus 2 per region index', () {
      final data = ItemVariationData(
        itemCount: 4,
        shortDeltaCount: 2,
        regionIndexCount: 3,
        regionIndexes: [0, 1, 2],
      );

      expect(data.size, 6 + 2 * 3);
    });
  });

  group('ItemVariationData round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final data = ItemVariationData(
        itemCount: 10,
        shortDeltaCount: 5,
        regionIndexCount: 2,
        regionIndexes: [0, 3],
      );
      final bytes = ByteData(data.size);

      data.encodeToBinary(bytes);
      final decoded = ItemVariationData.fromByteData(bytes);

      expect(decoded.itemCount, 10);
      expect(decoded.shortDeltaCount, 5);
      expect(decoded.regionIndexCount, 2);
      expect(decoded.regionIndexes, [0, 3]);
    });

    test('round-trips an empty region index list', () {
      final data = ItemVariationData(
        itemCount: 1,
        shortDeltaCount: 0,
        regionIndexCount: 0,
        regionIndexes: [],
      );
      final bytes = ByteData(data.size);

      data.encodeToBinary(bytes);
      final decoded = ItemVariationData.fromByteData(bytes);

      expect(decoded.regionIndexes, isEmpty);
    });
  });
}
