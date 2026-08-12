import 'dart:typed_data';

import '../../../common/codable/binary.dart';

const kSequentialMapGroupSize = 12;

/// One run of a format 12 subtable.
class SequentialMapGroup implements BinaryCodable {
  const SequentialMapGroup({
    required this.startCharCode,
    required this.endCharCode,
    required this.startGlyphID,
  });

  factory SequentialMapGroup.fromByteData(ByteData byteData, int offset) =>
      SequentialMapGroup(
        startCharCode: byteData.getUint32(offset),
        endCharCode: byteData.getUint32(offset + 4),
        startGlyphID: byteData.getUint32(offset + 8),
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
