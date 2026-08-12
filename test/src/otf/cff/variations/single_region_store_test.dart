import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/variations/single_region_store.dart';
import 'package:fontify_plus/src/otf/cff/variations/variation_store_data.dart';
import 'package:test/test.dart';

/// The exact bytes `SingleRegionVariationStore().build()` encoded to before
/// the two-region shape existed, captured by running the encode against that
/// revision rather than against the code under test here.
///
/// Pasting them literally is the point: the no-default-configured path must
/// keep emitting the same font bytes it always has, and a byte-identity claim
/// checked against a freshly computed expectation would only prove the code
/// agrees with itself.
const _kOneRegionBytesFromMaster = <int>[
  0x00, 0x1E, // length, excluding itself
  0x00, 0x01, // format
  0x00, 0x00, 0x00, 0x0C, // variationRegionListOffset
  0x00, 0x01, // itemVariationDataCount
  0x00, 0x00, 0x00, 0x16, // itemVariationDataOffsets[0]
  0x00, 0x01, // axisCount
  0x00, 0x01, // regionCount
  0xC0, 0x00, 0xC0, 0x00, 0x00, 0x00, // region 0: -1, -1, 0
  0x00, 0x00, // itemCount
  0x00, 0x00, // shortDeltaCount
  0x00, 0x01, // regionIndexCount
  0x00, 0x00, // regionIndexes[0]
];

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

    test('two regions: min-side peaks at -1, max-side peaks at +1', () {
      final data = SingleRegionVariationStore(regionCount: 2).build();
      final regions = data.store.variationRegionList.regions;

      expect(regions, hasLength(2));
      expect(regions[0].startCoord, 0xC000); // -1.0
      expect(regions[0].peakCoord, 0xC000);
      expect(regions[0].endCoord, 0x0000); //  0.0
      expect(regions[1].startCoord, 0x0000);
      expect(regions[1].peakCoord, 0x4000); // +1.0
      expect(regions[1].endCoord, 0x4000);
    });

    test('the one-region shape is unchanged', () {
      // Regression: this is the whole byte-identity argument for the
      // no-default-configured path. Compare byte-for-byte against a build from
      // before this task, not just field-by-field.
      final data = SingleRegionVariationStore().build();
      final bytes = ByteData(data.size);
      data.encodeToBinary(bytes);

      expect(bytes.buffer.asUint8List(), _kOneRegionBytesFromMaster);
    });

    test('regionCount other than 1 or 2 is still rejected', () {
      expect(
        () => SingleRegionVariationStore(regionCount: 3),
        throwsArgumentError,
      );
      expect(
        () => SingleRegionVariationStore(regionCount: 0),
        throwsArgumentError,
      );
    });

    test('the subtable advertises both region indexes', () {
      final data = SingleRegionVariationStore(regionCount: 2).build().store;
      final subtable = data.itemVariationDataList.single;

      expect(subtable.regionIndexCount, 2);
      expect(subtable.regionIndexes, [0, 1]);
    });

    test('the two-region store round-trips through the package reader', () {
      // The region list and the subtable both grow, and each is reached by an
      // offset the encoder recomputes; a reader getting back what was written
      // is what proves those offsets moved together.
      final data = SingleRegionVariationStore(regionCount: 2).build();
      final bytes = ByteData(data.size);
      data.encodeToBinary(bytes);

      final read = VariationStoreData.fromByteData(bytes);

      expect(read.length, data.store.size);
      expect(read.store.variationRegionList.regionCount, 2);
      expect(read.store.variationRegionList.regions.map((r) => r.peakCoord), [
        0xC000,
        0x4000,
      ]);
      expect(read.store.itemVariationDataList.single.regionIndexes, [0, 1]);
    });
  });
}
