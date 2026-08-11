import 'dart:typed_data';

import '../../../utils/otf.dart';
import '../../debugger.dart';
import '../table_record_entry.dart';
import 'os2_table.dart';
import 'os2_version.dart';
import 'os2_version_fields.dart';

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
    version: version,
    version0: OS2Version0Fields(
      xAvgCharWidth: byteData.getInt16(entry.offset + 2),
      usWeightClass: byteData.getUint16(entry.offset + 4),
      usWidthClass: byteData.getUint16(entry.offset + 6),
      fsType: byteData.getUint16(entry.offset + 8),
      ySubscriptXSize: byteData.getInt16(entry.offset + 10),
      ySubscriptYSize: byteData.getInt16(entry.offset + 12),
      ySubscriptXOffset: byteData.getInt16(entry.offset + 14),
      ySubscriptYOffset: byteData.getInt16(entry.offset + 16),
      ySuperscriptXSize: byteData.getInt16(entry.offset + 18),
      ySuperscriptYSize: byteData.getInt16(entry.offset + 20),
      ySuperscriptXOffset: byteData.getInt16(entry.offset + 22),
      ySuperscriptYOffset: byteData.getInt16(entry.offset + 24),
      yStrikeoutSize: byteData.getInt16(entry.offset + 26),
      yStrikeoutPosition: byteData.getInt16(entry.offset + 28),
      sFamilyClass: byteData.getInt16(entry.offset + 30),
      panose: List.generate(
        10,
        (i) => byteData.getUint8(entry.offset + 32 + i),
      ),
      ulUnicodeRange1: byteData.getUint32(entry.offset + 42),
      ulUnicodeRange2: byteData.getUint32(entry.offset + 46),
      ulUnicodeRange3: byteData.getUint32(entry.offset + 50),
      ulUnicodeRange4: byteData.getUint32(entry.offset + 54),
      achVendID: byteData.getTag(entry.offset + 58),
      fsSelection: byteData.getUint16(entry.offset + 62),
      usFirstCharIndex: byteData.getUint16(entry.offset + 64),
      usLastCharIndex: byteData.getUint16(entry.offset + 66),
      sTypoAscender: byteData.getInt16(entry.offset + 68),
      sTypoDescender: byteData.getInt16(entry.offset + 70),
      sTypoLineGap: byteData.getInt16(entry.offset + 72),
      usWinAscent: byteData.getUint16(entry.offset + 74),
      usWinDescent: byteData.getUint16(entry.offset + 76),
    ),
    version1: !isV1
        ? null
        : OS2Version1Fields(
            ulCodePageRange1: byteData.getUint32(entry.offset + 78),
            ulCodePageRange2: byteData.getUint32(entry.offset + 82),
          ),
    version4: !isV4
        ? null
        : OS2Version4Fields(
            sxHeight: byteData.getInt16(entry.offset + 86),
            sCapHeight: byteData.getInt16(entry.offset + 88),
            usDefaultChar: byteData.getUint16(entry.offset + 90),
            usBreakChar: byteData.getUint16(entry.offset + 92),
            usMaxContext: byteData.getUint16(entry.offset + 94),
          ),
    version5: !isV5
        ? null
        : OS2Version5Fields(
            usLowerOpticalPointSize: byteData.getUint16(entry.offset + 96),
            usUpperOpticalPointSize: byteData.getUint16(entry.offset + 98),
          ),
  );
}
