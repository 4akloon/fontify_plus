import 'dart:typed_data';

import '../../../utils/otf.dart';
import '../../debugger.dart';
import 'os2_table.dart';
import 'os2_version.dart';

/// Writes [table] out, stopping after the fields its version declares.
void encodeOS2Table(OS2Table table, ByteData byteData) {
  final version = table.version;

  if (version > kOS2Version5) {
    debuggerOTF.debugUnsupportedTableVersion(kOS2Tag, version);
  }

  byteData
    ..setInt16(0, version)
    ..setInt16(2, table.xAvgCharWidth)
    ..setUint16(4, table.usWeightClass)
    ..setUint16(6, table.usWidthClass)
    ..setUint16(8, table.fsType)
    ..setInt16(10, table.ySubscriptXSize)
    ..setInt16(12, table.ySubscriptYSize)
    ..setInt16(14, table.ySubscriptXOffset)
    ..setInt16(16, table.ySubscriptYOffset)
    ..setInt16(18, table.ySuperscriptXSize)
    ..setInt16(20, table.ySuperscriptYSize)
    ..setInt16(22, table.ySuperscriptXOffset)
    ..setInt16(24, table.ySuperscriptYOffset)
    ..setInt16(26, table.yStrikeoutSize)
    ..setInt16(28, table.yStrikeoutPosition)
    ..setInt16(30, table.sFamilyClass)
    ..setUint32(42, table.ulUnicodeRange1)
    ..setUint32(46, table.ulUnicodeRange2)
    ..setUint32(50, table.ulUnicodeRange3)
    ..setUint32(54, table.ulUnicodeRange4)
    ..setTag(58, table.achVendID)
    ..setUint16(62, table.fsSelection)
    ..setUint16(64, table.usFirstCharIndex)
    ..setUint16(66, table.usLastCharIndex)
    ..setInt16(68, table.sTypoAscender)
    ..setInt16(70, table.sTypoDescender)
    ..setInt16(72, table.sTypoLineGap)
    ..setUint16(74, table.usWinAscent)
    ..setUint16(76, table.usWinDescent);

  for (var i = 0; i < table.panose.length; i++) {
    byteData.setUint8(32 + i, table.panose[i]);
  }

  if (version >= kOS2Version1) {
    byteData
      ..setUint32(78, table.ulCodePageRange1!)
      ..setUint32(82, table.ulCodePageRange2!);
  }

  if (version >= kOS2Version4) {
    byteData
      ..setInt16(86, table.sxHeight!)
      ..setInt16(88, table.sCapHeight!)
      ..setUint16(90, table.usDefaultChar!)
      ..setUint16(92, table.usBreakChar!)
      ..setUint16(94, table.usMaxContext!);
  }

  if (version >= kOS2Version5) {
    byteData
      ..setUint16(96, table.usLowerOpticalPointSize!)
      ..setUint16(98, table.usUpperOpticalPointSize!);
  }
}
