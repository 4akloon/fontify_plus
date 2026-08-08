import 'dart:typed_data';

import '../../../common/codable/binary.dart';

const kSequentialMapGroupSize = 12;

/// One run of a format 12 subtable.
class SequentialMapGroup implements BinaryCodable {
  SequentialMapGroup(this.startCharCode, this.endCharCode, this.startGlyphID);

  factory SequentialMapGroup.fromByteData(ByteData byteData, int offset) =>
      SequentialMapGroup(
        byteData.getUint32(offset),
        byteData.getUint32(offset + 4),
        byteData.getUint32(offset + 8),
      );

  final int startCharCode;
  final int endCharCode;
  final int startGlyphID;

  @override
  int get size => kSequentialMapGroupSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint32(0, startCharCode)
      ..setUint32(4, endCharCode)
      ..setUint32(8, startGlyphID);
  }
}
