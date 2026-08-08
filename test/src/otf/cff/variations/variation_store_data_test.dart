import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/variations/item_variation_data.dart';
import 'package:fontify_plus/src/otf/cff/variations/item_variation_store.dart';
import 'package:fontify_plus/src/otf/cff/variations/region_axis_coordinates.dart';
import 'package:fontify_plus/src/otf/cff/variations/variation_region_list.dart';
import 'package:fontify_plus/src/otf/cff/variations/variation_store_data.dart';
import 'package:test/test.dart';

// itemVariationDataCount/Offsets/variationRegionListOffset start consistent
// with the subtable list — see item_variation_store_test.dart for why.
ItemVariationStore _store() => ItemVariationStore(
      1,
      12,
      1,
      [0],
      VariationRegionList(1, 1, [RegionAxisCoordinates(0, 0x4000, 0x8000)]),
      [
        ItemVariationData(2, 1, 1, [0]),
      ],
    );

void main() {
  group('VariationStoreData.size', () {
    test('is 2 bytes plus the store\'s own size', () {
      final data = VariationStoreData(0, _store());

      expect(data.size, 2 + _store().size);
    });
  });

  group('VariationStoreData.encodeToBinary', () {
    test('recomputes length from the encoded store size', () {
      final data = VariationStoreData(0, _store());
      final bytes = ByteData(data.size);

      data.encodeToBinary(bytes);

      expect(data.length, _store().size);
    });
  });

  group('VariationStoreData round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final data = VariationStoreData(0, _store());
      final bytes = ByteData(data.size);

      data.encodeToBinary(bytes);
      final decoded = VariationStoreData.fromByteData(bytes);

      expect(decoded.length, data.length);
      expect(decoded.store.itemVariationDataList.single.itemCount, 2);
    });
  });
}
