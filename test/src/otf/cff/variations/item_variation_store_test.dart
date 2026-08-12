import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/variations/item_variation_data.dart';
import 'package:fontify_plus/src/otf/cff/variations/item_variation_store.dart';
import 'package:fontify_plus/src/otf/cff/variations/region_axis_coordinates.dart';
import 'package:fontify_plus/src/otf/cff/variations/variation_region_list.dart';
import 'package:test/test.dart';

// itemVariationDataCount/Offsets/variationRegionListOffset start consistent
// with the subtable list, the way ItemVariationStore.fromByteData always
// produces them — encodeToBinary recomputes them, but size (called before
// encoding, as every BinaryEncodable expects) trusts the stored count as-is.
ItemVariationStore _store() => ItemVariationStore(
  format: 1,
  // 8 fixed bytes + 4 bytes for the one subtable offset
  variationRegionListOffset: 12,
  itemVariationDataCount: 1,
  itemVariationDataOffsets: [0], // overwritten by encodeToBinary
  variationRegionList: const VariationRegionList(
    axisCount: 1,
    regionCount: 1,
    regions: [
      RegionAxisCoordinates(startCoord: 0, peakCoord: 0x4000, endCoord: 0x8000),
    ],
  ),
  itemVariationDataList: [
    const ItemVariationData(
      itemCount: 2,
      shortDeltaCount: 1,
      regionIndexCount: 1,
      regionIndexes: [0],
    ),
  ],
);

void main() {
  group('ItemVariationStore.encodeToBinary', () {
    test('recomputes itemVariationDataCount from the subtable list', () {
      final store = _store();
      final bytes = ByteData(store.size);

      store.encodeToBinary(bytes);

      expect(store.itemVariationDataCount, 1);
    });

    test('places the region list right after the offset table', () {
      final store = _store();
      final bytes = ByteData(store.size);

      store.encodeToBinary(bytes);

      // 8 fixed bytes + 4 bytes per one subtable offset.
      expect(store.variationRegionListOffset, 12);
    });
  });

  group('ItemVariationStore round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final store = _store();
      final bytes = ByteData(store.size);
      store.encodeToBinary(bytes);

      final decoded = ItemVariationStore.fromByteData(bytes);

      expect(decoded.format, 1);
      expect(decoded.itemVariationDataCount, 1);
      expect(decoded.variationRegionList.regionCount, 1);
      expect(decoded.itemVariationDataList.single.itemCount, 2);
      expect(decoded.itemVariationDataList.single.regionIndexes, [0]);
    });

    test('round-trips multiple subtables at their own offsets', () {
      final store = ItemVariationStore(
        format: 1,
        // 8 fixed bytes + 4 bytes per two subtable offsets
        variationRegionListOffset: 16,
        itemVariationDataCount: 2,
        itemVariationDataOffsets: [0, 0], // overwritten by encodeToBinary
        variationRegionList: const VariationRegionList(
          axisCount: 1,
          regionCount: 1,
          regions: [
            RegionAxisCoordinates(
              startCoord: 0,
              peakCoord: 0x4000,
              endCoord: 0x8000,
            ),
          ],
        ),
        itemVariationDataList: [
          const ItemVariationData(
            itemCount: 2,
            shortDeltaCount: 1,
            regionIndexCount: 1,
            regionIndexes: [0],
          ),
          const ItemVariationData(
            itemCount: 3,
            shortDeltaCount: 1,
            regionIndexCount: 1,
            regionIndexes: [0],
          ),
        ],
      );
      final bytes = ByteData(store.size);
      store.encodeToBinary(bytes);

      final decoded = ItemVariationStore.fromByteData(bytes);

      expect(
        decoded.itemVariationDataList.map((d) => d.itemCount),
        [2, 3],
      );
    });
  });
}
