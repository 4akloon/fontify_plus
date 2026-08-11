import 'dart:typed_data';

import '../../../common/codable/binary.dart';

const kRegionAxisCoordinatesSize = 6;

/// One axis's extent within a variation region.
class RegionAxisCoordinates extends BinaryCodable {
  const RegionAxisCoordinates({
    required this.startCoord,
    required this.peakCoord,
    required this.endCoord,
  });

  factory RegionAxisCoordinates.fromByteData(ByteData byteData) {
    // NOTE: not converting F2DOT14, because variations are ignored anyway
    return RegionAxisCoordinates(
      startCoord: byteData.getUint16(0),
      peakCoord: byteData.getUint16(2),
      endCoord: byteData.getUint16(4),
    );
  }

  final int startCoord;
  final int peakCoord;
  final int endCoord;

  @override
  int get size => kRegionAxisCoordinatesSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, startCoord)
      ..setUint16(2, peakCoord)
      ..setUint16(4, endCoord);
  }
}
