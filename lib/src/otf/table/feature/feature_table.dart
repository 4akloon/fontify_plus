import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import 'feature_record.dart';

/// The lookups one feature applies.
class FeatureTable implements BinaryCodable {
  const FeatureTable({
    required this.featureParams,
    required this.lookupIndexCount,
    required this.lookupListIndices,
  });

  factory FeatureTable.fromByteData(
    ByteData byteData,
    int offset,
    FeatureRecord record,
  ) {
    offset += record.featureOffset!;

    final lookupIndexCount = byteData.getUint16(offset + 2);

    return FeatureTable(
      featureParams: byteData.getUint16(offset),
      lookupIndexCount: lookupIndexCount,
      lookupListIndices: List.generate(
        lookupIndexCount,
        (i) => byteData.getUint16(offset + 4 + i * 2),
      ),
    );
  }

  final int featureParams;
  final int lookupIndexCount;
  final List<int> lookupListIndices;

  @override
  int get size => 4 + 2 * lookupIndexCount;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, featureParams)
      ..setUint16(2, lookupIndexCount);

    for (var i = 0; i < lookupIndexCount; i++) {
      byteData.setInt16(4 + 2 * i, lookupListIndices[i]);
    }
  }
}
