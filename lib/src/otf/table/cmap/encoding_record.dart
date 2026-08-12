import 'dart:typed_data';

import '../../../common/codable/binary.dart';

const kEncodingRecordSize = 8;

/// Points a (platform, encoding) pair at one of the table's subtables.
class EncodingRecord implements BinaryCodable {
  EncodingRecord({
    required this.platformID,
    required this.encodingID,
    required this.offset,
  });

  EncodingRecord.create(this.platformID, this.encodingID) : offset = null;

  factory EncodingRecord.fromByteData(ByteData byteData, int offset) =>
      EncodingRecord(
        platformID: byteData.getUint16(offset),
        encodingID: byteData.getUint16(offset + 2),
        offset: byteData.getUint32(offset + 4),
      );

  final int platformID;
  final int encodingID;

  /// Filled in while encoding, once the subtable layout is known.
  int? offset;

  @override
  int get size => kEncodingRecordSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, platformID)
      ..setUint16(2, encodingID)
      ..setUint32(4, offset!);
  }
}
