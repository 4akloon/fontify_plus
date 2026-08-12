import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/variations/single_region_store.dart';
import 'package:fontify_plus/src/otf/cff/variations/variation_store_data.dart';
import 'package:test/test.dart';

void main() {
  group('single region variation store', () {
    test('the region spans the whole axis and peaks at the minimum', () {
      final store = SingleRegionVariationStore().build().store;
      final region = store.variationRegionList.regions.single;

      // F2Dot14. The fvar default sits at the axis maximum, so normalized
      // design space is [-1, 0]: -1 is the minimum stroke width, 0 the
      // default. 0xC000 is -1.0, 0x0000 is 0.0.
      expect(region.startCoord, 0xC000);
      expect(region.peakCoord, 0xC000);
      expect(region.endCoord, 0x0000);
    });

    test('the subtable carries no delta sets, only a region count', () {
      // CFF2 keeps its deltas inside the charstrings. The subtable exists so
      // a `blend` at vsindex 0 knows how many deltas follow each value.
      final data = SingleRegionVariationStore()
          .build()
          .store
          .itemVariationDataList
          .single;

      expect(data.itemCount, 0);
      expect(data.shortDeltaCount, 0);
      expect(data.regionIndexCount, 1);
      expect(data.regionIndexes, [0]);
    });

    test('it round-trips through the package reader', () {
      final data = SingleRegionVariationStore().build();
      final bytes = ByteData(data.size);
      data.encodeToBinary(bytes);

      final read = VariationStoreData.fromByteData(bytes);

      expect(read.length, data.store.size);
      expect(read.store.format, 1);
      expect(read.store.itemVariationDataCount, 1);
      expect(read.store.variationRegionList.axisCount, 1);
      expect(read.store.variationRegionList.regionCount, 1);
      expect(read.store.variationRegionList.regions.single.peakCoord, 0xC000);
      expect(read.store.itemVariationDataList.single.regionIndexCount, 1);
    });

    test('every declared byte is written', () {
      final data = SingleRegionVariationStore().build();
      final bytes = ByteData(data.size);
      data.encodeToBinary(bytes);

      // 2 (length) + 8 (store header) + 4 (one subtable offset)
      // + 4 + 6 (region list) + 6 + 2 (subtable) = 32
      expect(data.size, 32);
      expect(bytes.getUint16(0), 30); // length excludes itself
      expect(bytes.getUint16(2), 1); // format
    });
  });
}
