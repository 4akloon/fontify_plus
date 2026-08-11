import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import '../table_record_entry.dart';

const kPostHeaderSize = 32;

/// The fixed part of the `post` table, present in every version.
class PostScriptTableHeader implements BinaryCodable {
  PostScriptTableHeader({
    required this.version,
    required this.italicAngle,
    required this.underlinePosition,
    required this.underlineThickness,
    required this.isFixedPitch,
    required this.minMemType42,
    required this.maxMemType42,
    required this.minMemType1,
    required this.maxMemType1,
  });

  factory PostScriptTableHeader.fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
  ) => PostScriptTableHeader(
    version: Revision.fromInt32(byteData.getInt32(entry.offset)),
    italicAngle: byteData.getFixed(entry.offset + 4),
    underlinePosition: byteData.getFWord(entry.offset + 8),
    underlineThickness: byteData.getFWord(entry.offset + 10),
    isFixedPitch: byteData.getUint32(entry.offset + 12),
    minMemType42: byteData.getUint32(entry.offset + 16),
    maxMemType42: byteData.getUint32(entry.offset + 20),
    minMemType1: byteData.getUint32(entry.offset + 24),
    maxMemType1: byteData.getUint32(entry.offset + 28),
  );

  factory PostScriptTableHeader.create(Revision version) =>
      PostScriptTableHeader(
        version: version,
        italicAngle: 0, // upright text
        underlinePosition: 0,
        underlineThickness: 0,
        isFixedPitch: 0, // proportionally spaced
        minMemType42: 0,
        maxMemType42: 0,
        minMemType1: 0,
        maxMemType1: 0,
      );

  final Revision version;
  final int italicAngle;
  final int underlinePosition;
  final int underlineThickness;
  final int isFixedPitch;
  final int minMemType42;
  final int maxMemType42;
  final int minMemType1;
  final int maxMemType1;

  @override
  int get size => kPostHeaderSize;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setInt32(0, version.int32value)
      ..setFixed(4, italicAngle)
      ..setFWord(8, underlinePosition)
      ..setFWord(10, underlineThickness)
      ..setUint32(12, isFixedPitch)
      ..setUint32(16, minMemType42)
      ..setUint32(20, maxMemType42)
      ..setUint32(24, minMemType1)
      ..setUint32(28, maxMemType1);
  }
}
