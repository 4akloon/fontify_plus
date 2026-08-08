import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';

const kFeatureRecordSize = 6;

/// Names a layout feature and points at its table.
class FeatureRecord implements BinaryCodable {
  FeatureRecord(this.featureTag, this.featureOffset);

  factory FeatureRecord.fromByteData(ByteData byteData, int offset) =>
      FeatureRecord(byteData.getTag(offset), byteData.getUint16(offset + 4));

  final String featureTag;

  /// Filled in while encoding, once the table layout is known.
  int? featureOffset;

  @override
  int get size => kFeatureRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setTag(0, featureTag)
      ..setUint16(4, featureOffset!);
  }
}
