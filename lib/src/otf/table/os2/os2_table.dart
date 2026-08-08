import 'dart:typed_data';

import '../abstract.dart';
import '../cmap.dart';
import '../gsub.dart';
import '../head.dart';
import '../hhea.dart';
import '../hmtx.dart';
import '../table_record_entry.dart';
import 'os2_builder.dart';
import 'os2_encoder.dart';
import 'os2_reader.dart';
import 'os2_version.dart';

/// The `OS/2` table: metrics and classification Windows and layout engines
/// read.
///
/// Fields are grouped by the version that introduced them; everything past
/// version 0 is nullable because a lower-version table simply ends early.
class OS2Table extends FontTable {
  OS2Table(
    super.entry,
    this.version,
    this.xAvgCharWidth,
    this.usWeightClass,
    this.usWidthClass,
    this.fsType,
    this.ySubscriptXSize,
    this.ySubscriptYSize,
    this.ySubscriptXOffset,
    this.ySubscriptYOffset,
    this.ySuperscriptXSize,
    this.ySuperscriptYSize,
    this.ySuperscriptXOffset,
    this.ySuperscriptYOffset,
    this.yStrikeoutSize,
    this.yStrikeoutPosition,
    this.sFamilyClass,
    this.panose,
    this.ulUnicodeRange1,
    this.ulUnicodeRange2,
    this.ulUnicodeRange3,
    this.ulUnicodeRange4,
    this.achVendID,
    this.fsSelection,
    this.usFirstCharIndex,
    this.usLastCharIndex,
    this.sTypoAscender,
    this.sTypoDescender,
    this.sTypoLineGap,
    this.usWinAscent,
    this.usWinDescent,
    this.ulCodePageRange1,
    this.ulCodePageRange2,
    this.sxHeight,
    this.sCapHeight,
    this.usDefaultChar,
    this.usBreakChar,
    this.usMaxContext,
    this.usLowerOpticalPointSize,
    this.usUpperOpticalPointSize,
  ) : super.fromTableRecordEntry();

  factory OS2Table.fromByteData(ByteData byteData, TableRecordEntry entry) =>
      readOS2Table(byteData, entry);

  factory OS2Table.create(
    HorizontalMetricsTable hmtx,
    HeaderTable head,
    HorizontalHeaderTable hhea,
    CharacterToGlyphTable cmap,
    GlyphSubstitutionTable gsub,
    String achVendID, {
    int version = kOS2Version5,
  }) =>
      buildOS2Table(
        hmtx,
        head,
        hhea,
        cmap,
        gsub,
        achVendID,
        version: version,
      );

  final int version;

  // Version 0
  final int xAvgCharWidth;
  final int usWeightClass;
  final int usWidthClass;
  final int fsType;
  final int ySubscriptXSize;
  final int ySubscriptYSize;
  final int ySubscriptXOffset;
  final int ySubscriptYOffset;
  final int ySuperscriptXSize;
  final int ySuperscriptYSize;
  final int ySuperscriptXOffset;
  final int ySuperscriptYOffset;
  final int yStrikeoutSize;
  final int yStrikeoutPosition;
  final int sFamilyClass;
  final List<int> panose;
  final int ulUnicodeRange1;
  final int ulUnicodeRange2;
  final int ulUnicodeRange3;
  final int ulUnicodeRange4;
  final String achVendID;
  final int fsSelection;
  final int usFirstCharIndex;
  final int usLastCharIndex;
  final int sTypoAscender;
  final int sTypoDescender;
  final int sTypoLineGap;
  final int usWinAscent;
  final int usWinDescent;

  // Version 1
  final int? ulCodePageRange1;
  final int? ulCodePageRange2;

  // Version 4
  final int? sxHeight;
  final int? sCapHeight;
  final int? usDefaultChar;
  final int? usBreakChar;
  final int? usMaxContext;

  // Version 5
  final int? usLowerOpticalPointSize;
  final int? usUpperOpticalPointSize;

  @override
  int get size {
    var size = 0;

    for (final e in kOS2VersionDataSize.entries) {
      if (e.key > version) {
        break;
      }

      size += e.value;
    }

    return size;
  }

  @override
  void encodeToBinary(ByteData byteData) => encodeOS2Table(this, byteData);
}
