import 'dart:typed_data';

import '../../../common/codable/binary.dart';

const kNameRecordSize = 12;

/// Where one name string lives, and which platform and name ID it is for.
class NameRecord implements BinaryCodable {
  NameRecord({
    required this.platformID,
    required this.encodingID,
    required this.languageID,
    required this.nameID,
    required this.length,
    required this.offset,
  });

  /// A record with the platform fields filled in and the rest left for
  /// [copyWith] once the string is known.
  const NameRecord.template({
    required this.platformID,
    required this.encodingID,
    required this.languageID,
  }) : nameID = -1,
       length = -1,
       offset = -1;

  factory NameRecord.fromByteData(ByteData byteData, int offset) => NameRecord(
    platformID: byteData.getUint16(offset),
    encodingID: byteData.getUint16(offset + 2),
    languageID: byteData.getUint16(offset + 4),
    nameID: byteData.getUint16(offset + 6),
    length: byteData.getUint16(offset + 8),
    offset: byteData.getUint16(offset + 10),
  );

  final int platformID;
  final int encodingID;
  final int languageID;
  final int nameID;
  final int length;
  final int offset;

  @override
  int get size => kNameRecordSize;

  NameRecord copyWith({
    int? platformID,
    int? encodingID,
    int? languageID,
    int? nameID,
    int? length,
    int? offset,
  }) => NameRecord(
    platformID: platformID ?? this.platformID,
    encodingID: encodingID ?? this.encodingID,
    languageID: languageID ?? this.languageID,
    nameID: nameID ?? this.nameID,
    length: length ?? this.length,
    offset: offset ?? this.offset,
  );

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setUint16(0, platformID)
      ..setUint16(2, encodingID)
      ..setUint16(4, languageID)
      ..setUint16(6, nameID)
      ..setUint16(8, length)
      ..setUint16(10, offset);
  }
}
