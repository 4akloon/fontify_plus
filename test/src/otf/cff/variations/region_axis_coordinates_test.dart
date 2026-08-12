import 'dart:typed_data';

import 'package:fontify_plus/src/otf/cff/variations/region_axis_coordinates.dart';
import 'package:test/test.dart';

void main() {
  group('RegionAxisCoordinates', () {
    test('size is fixed at 6 bytes', () {
      const coords = RegionAxisCoordinates(
        startCoord: 0,
        peakCoord: 0x4000,
        endCoord: 0x8000,
      );

      expect(coords.size, 6);
    });

    test('round-trips through encodeToBinary and fromByteData', () {
      const coords = RegionAxisCoordinates(
        startCoord: 0,
        peakCoord: 0x4000,
        endCoord: 0x8000,
      );
      final bytes = ByteData(coords.size);

      coords.encodeToBinary(bytes);
      final decoded = RegionAxisCoordinates.fromByteData(bytes);

      expect(decoded.startCoord, 0);
      expect(decoded.peakCoord, 0x4000);
      expect(decoded.endCoord, 0x8000);
    });
  });
}
