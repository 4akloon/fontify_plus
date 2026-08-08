import 'dart:typed_data';

import '../../../utils/otf.dart';
import '../../debugger.dart';
import '../table_record_entry.dart';
import 'os2_table.dart';
import 'os2_version.dart';

/// Reads an OS/2 table out of an existing font.
OS2Table readOS2Table(ByteData byteData, TableRecordEntry entry) {
  final version = byteData.getInt16(entry.offset);

  final isV1 = version >= kOS2Version1;
  final isV4 = version >= kOS2Version4;
  final isV5 = version >= kOS2Version5;

  if (version > kOS2Version5) {
    debuggerOTF.debugUnsupportedTableVersion(kOS2Tag, version);
  }

  return OS2Table(
    entry,
    version,
    byteData.getInt16(entry.offset + 2),
    byteData.getUint16(entry.offset + 4),
    byteData.getUint16(entry.offset + 6),
    byteData.getUint16(entry.offset + 8),
    byteData.getInt16(entry.offset + 10),
    byteData.getInt16(entry.offset + 12),
    byteData.getInt16(entry.offset + 14),
    byteData.getInt16(entry.offset + 16),
    byteData.getInt16(entry.offset + 18),
    byteData.getInt16(entry.offset + 20),
    byteData.getInt16(entry.offset + 22),
    byteData.getInt16(entry.offset + 24),
    byteData.getInt16(entry.offset + 26),
    byteData.getInt16(entry.offset + 28),
    byteData.getInt16(entry.offset + 30),
    List.generate(10, (i) => byteData.getUint8(entry.offset + 32 + i)),
    byteData.getUint32(entry.offset + 42),
    byteData.getUint32(entry.offset + 46),
    byteData.getUint32(entry.offset + 50),
    byteData.getUint32(entry.offset + 54),
    byteData.getTag(entry.offset + 58),
    byteData.getUint16(entry.offset + 62),
    byteData.getUint16(entry.offset + 64),
    byteData.getUint16(entry.offset + 66),
    byteData.getInt16(entry.offset + 68),
    byteData.getInt16(entry.offset + 70),
    byteData.getInt16(entry.offset + 72),
    byteData.getUint16(entry.offset + 74),
    byteData.getUint16(entry.offset + 76),
    !isV1 ? null : byteData.getUint32(entry.offset + 78),
    !isV1 ? null : byteData.getUint32(entry.offset + 82),
    !isV4 ? null : byteData.getInt16(entry.offset + 86),
    !isV4 ? null : byteData.getInt16(entry.offset + 88),
    !isV4 ? null : byteData.getUint16(entry.offset + 90),
    !isV4 ? null : byteData.getUint16(entry.offset + 92),
    !isV4 ? null : byteData.getUint16(entry.offset + 94),
    !isV5 ? null : byteData.getUint16(entry.offset + 96),
    !isV5 ? null : byteData.getUint16(entry.offset + 98),
  );
}
