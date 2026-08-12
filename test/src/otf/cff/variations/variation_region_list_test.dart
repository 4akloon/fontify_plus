import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/variations/region_axis_coordinates.dart';
import 'package:fontify_plus/src/otf/cff/variations/variation_region_list.dart';
import 'package:test/test.dart';

RegionAxisCoordinates _coords(int i) => RegionAxisCoordinates(
  startCoord: 0,
  peakCoord: 0x1000 * i,
  endCoord: 0x4000,
);

void main() {
  group('VariationRegionList.size', () {
    test('is 4 bytes plus 6 per axis per region', () {
      final list = VariationRegionList(
        axisCount: 2,
        regionCount: 3,
        regions: [
          for (var i = 0; i < 6; i++) _coords(i),
        ],
      );

      expect(list.size, 4 + 3 * 2 * 6);
    });
  });

  group('VariationRegionList round trip', () {
    test('round-trips a single-axis, single-region list', () {
      final list = VariationRegionList(
        axisCount: 1,
        regionCount: 1,
        regions: [_coords(1)],
      );
      final bytes = ByteData(list.size);

      list.encodeToBinary(bytes);
      final decoded = VariationRegionList.fromByteData(bytes);

      expect(decoded.axisCount, 1);
      expect(decoded.regionCount, 1);
      expect(decoded.regions.single.peakCoord, 0x1000);
    });

    test('lays regions out row-major (region, then axis within it)', () {
      // 2 regions of 2 axes each; region 1's axes must decode as regions[2]
      // and regions[3], not interleaved with region 0's.
      final list = VariationRegionList(
        axisCount: 2,
        regionCount: 2,
        regions: [
          _coords(0),
          _coords(1),
          _coords(2),
          _coords(3),
        ],
      );
      final bytes = ByteData(list.size);

      list.encodeToBinary(bytes);
      final decoded = VariationRegionList.fromByteData(bytes);

      expect(
        decoded.regions.map((r) => r.peakCoord),
        [0, 0x1000, 0x2000, 0x3000],
      );
    });
  });
}
