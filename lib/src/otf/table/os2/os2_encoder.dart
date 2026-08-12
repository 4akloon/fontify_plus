import 'dart:typed_data';

import '../../../utils/otf.dart';
import '../../debugger.dart';
import 'os2_table.dart';
import 'os2_version.dart';

/// Writes [table] out, stopping after the last version group it carries.
///
/// The offsets are the format's, not a running cursor, so the order the
/// fields appear in below does not affect the bytes — but it is the order the
/// spec lists them in, and it stays that way.
void encodeOS2Table(OS2Table table, ByteData byteData) {
  final version = table.version;

  if (version > kOS2Version5) {
    debuggerOTF.debugUnsupportedTableVersion(kOS2Tag, version);
  }

  final version0 = table.version0;

  byteData
    ..setInt16(0, version)
    ..setInt16(2, version0.xAvgCharWidth)
    ..setUint16(4, version0.usWeightClass)
    ..setUint16(6, version0.usWidthClass)
    ..setUint16(8, version0.fsType)
    ..setInt16(10, version0.ySubscriptXSize)
    ..setInt16(12, version0.ySubscriptYSize)
    ..setInt16(14, version0.ySubscriptXOffset)
    ..setInt16(16, version0.ySubscriptYOffset)
    ..setInt16(18, version0.ySuperscriptXSize)
    ..setInt16(20, version0.ySuperscriptYSize)
    ..setInt16(22, version0.ySuperscriptXOffset)
    ..setInt16(24, version0.ySuperscriptYOffset)
    ..setInt16(26, version0.yStrikeoutSize)
    ..setInt16(28, version0.yStrikeoutPosition)
    ..setInt16(30, version0.sFamilyClass)
    ..setUint32(42, version0.ulUnicodeRange1)
    ..setUint32(46, version0.ulUnicodeRange2)
    ..setUint32(50, version0.ulUnicodeRange3)
    ..setUint32(54, version0.ulUnicodeRange4)
    ..setTag(58, version0.achVendID)
    ..setUint16(62, version0.fsSelection)
    ..setUint16(64, version0.usFirstCharIndex)
    ..setUint16(66, version0.usLastCharIndex)
    ..setInt16(68, version0.sTypoAscender)
    ..setInt16(70, version0.sTypoDescender)
    ..setInt16(72, version0.sTypoLineGap)
    ..setUint16(74, version0.usWinAscent)
    ..setUint16(76, version0.usWinDescent);

  for (var i = 0; i < version0.panose.length; i++) {
    byteData.setUint8(32 + i, version0.panose[i]);
  }

  // Walking the nesting rather than the shorthand getters: reaching the
  // version-4 block requires having written the version-1 one, which is the
  // format's own rule and now the code's shape as well. A present group is
  // the table's statement that its version declares those fields — the
  // constructor throws if the two disagree — so nothing here force-unwraps.
  if (table.version1 case final version1?) {
    byteData
      ..setUint32(78, version1.ulCodePageRange1)
      ..setUint32(82, version1.ulCodePageRange2);

    if (version1.version4 case final version4?) {
      byteData
        ..setInt16(86, version4.sxHeight)
        ..setInt16(88, version4.sCapHeight)
        ..setUint16(90, version4.usDefaultChar)
        ..setUint16(92, version4.usBreakChar)
        ..setUint16(94, version4.usMaxContext);

      if (version4.version5 case final version5?) {
        byteData
          ..setUint16(96, version5.usLowerOpticalPointSize)
          ..setUint16(98, version5.usUpperOpticalPointSize);
      }
    }
  }
}
