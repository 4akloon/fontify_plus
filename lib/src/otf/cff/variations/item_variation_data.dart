import 'dart:typed_data';

import '../../../common/codable/binary.dart';

/// Which variation regions one subtable's deltas apply to.
class ItemVariationData extends BinaryCodable {
  const ItemVariationData({
    required this.itemCount,
    required this.shortDeltaCount,
    required this.regionIndexCount,
    required this.regionIndexes,
  });

  factory ItemVariationData.fromByteData(ByteData byteData) {
    final regionIndexCount = byteData.getUint16(4);

    return ItemVariationData(
      itemCount: byteData.getUint16(0),
      shortDeltaCount: byteData.getUint16(2),
      regionIndexCount: regionIndexCount,
      regionIndexes: List.generate(
        regionIndexCount,
        (i) => byteData.getUint16(6 + 2 * i),
      ),
    );
  }

  final int itemCount;
  final int shortDeltaCount;
  final int regionIndexCount;
  final List<int> regionIndexes;

  @override
  int get size => 6 + 2 * regionIndexCount;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, itemCount)
      ..setUint16(2, shortDeltaCount)
      ..setUint16(4, regionIndexCount);

    for (var i = 0; i < regionIndexCount; i++) {
      byteData.setUint16(6 + 2 * i, regionIndexes[i]);
    }
  }
}
