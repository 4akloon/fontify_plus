import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import 'region_axis_coordinates.dart';

/// The regions of design space a variation store refers to.
class VariationRegionList extends BinaryCodable {
  VariationRegionList(this.axisCount, this.regionCount, this.regions);

  factory VariationRegionList.fromByteData(ByteData byteData) {
    final axisCount = byteData.getUint16(0);
    final regionCount = byteData.getUint16(2);

    final regions = [
      for (var r = 0; r < regionCount; r++)
        for (var a = 0; a < axisCount; a++)
          RegionAxisCoordinates.fromByteData(
            byteData.sublistView(
              4 + (a + r * axisCount) * kRegionAxisCoordinatesSize,
              kRegionAxisCoordinatesSize,
            ),
          ),
    ];

    return VariationRegionList(axisCount, regionCount, regions);
  }

  final int axisCount;
  final int regionCount;
  final List<RegionAxisCoordinates> regions;

  @override
  int get size => 4 + regionCount * axisCount * kRegionAxisCoordinatesSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, axisCount)
      ..setUint16(2, regionCount);

    for (var r = 0; r < regionCount; r++) {
      for (var a = 0; a < axisCount; a++) {
        final index = r * axisCount + a;

        regions[index].encodeToBinary(
          byteData.sublistView(
            4 + index * kRegionAxisCoordinatesSize,
            kRegionAxisCoordinatesSize,
          ),
        );
      }
    }
  }
}
