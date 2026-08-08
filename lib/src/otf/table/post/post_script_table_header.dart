import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import '../table_record_entry.dart';

const kPostHeaderSize = 32;

/// The fixed part of the `post` table, present in every version.
class PostScriptTableHeader implements BinaryCodable {
  PostScriptTableHeader(
    this.version,
    this.italicAngle,
    this.underlinePosition,
    this.underlineThickness,
    this.isFixedPitch,
    this.minMemType42,
    this.maxMemType42,
    this.minMemType1,
    this.maxMemType1,
  );

  factory PostScriptTableHeader.fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
  ) =>
      PostScriptTableHeader(
        Revision.fromInt32(byteData.getInt32(entry.offset)),
        byteData.getFixed(entry.offset + 4),
        byteData.getFWord(entry.offset + 8),
        byteData.getFWord(entry.offset + 10),
        byteData.getUint32(entry.offset + 12),
        byteData.getUint32(entry.offset + 16),
        byteData.getUint32(entry.offset + 20),
        byteData.getUint32(entry.offset + 24),
        byteData.getUint32(entry.offset + 28),
      );

  factory PostScriptTableHeader.create(Revision version) =>
      PostScriptTableHeader(
        version,
        0, // italicAngle - upright text
        0, // underlinePosition
        0, // underlineThickness
        0, // isFixedPitch - proportionally spaced
        0,
        0,
        0,
        0,
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
