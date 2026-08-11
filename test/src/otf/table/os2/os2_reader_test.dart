import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/os2/os2_encoder.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_reader.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_table.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_version.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

OS2Table _table(int version) => OS2Table(
  null,
  version: version,
  xAvgCharWidth: 500,
  usWeightClass: 400,
  usWidthClass: 5,
  fsType: 0,
  ySubscriptXSize: 650,
  ySubscriptYSize: 600,
  ySubscriptXOffset: 0,
  ySubscriptYOffset: 140,
  ySuperscriptXSize: 650,
  ySuperscriptYSize: 600,
  ySuperscriptXOffset: 0,
  ySuperscriptYOffset: 480,
  yStrikeoutSize: 100,
  yStrikeoutPosition: 260,
  sFamilyClass: 0,
  panose: [2, 0, 5, 3, 0, 0, 0, 0, 0, 0],
  ulUnicodeRange1: 1,
  ulUnicodeRange2: 0,
  ulUnicodeRange3: 0,
  ulUnicodeRange4: 0,
  achVendID: 'PfPl',
  fsSelection: 0x40,
  usFirstCharIndex: 0xE001,
  usLastCharIndex: 0xE0FF,
  sTypoAscender: 800,
  sTypoDescender: -200,
  sTypoLineGap: 0,
  usWinAscent: 800,
  usWinDescent: 200,
  ulCodePageRange1: version >= kOS2Version1 ? 1 : null,
  ulCodePageRange2: version >= kOS2Version1 ? 0 : null,
  sxHeight: version >= kOS2Version4 ? 500 : null,
  sCapHeight: version >= kOS2Version4 ? 700 : null,
  usDefaultChar: version >= kOS2Version4 ? 32 : null,
  usBreakChar: version >= kOS2Version4 ? 32 : null,
  usMaxContext: version >= kOS2Version4 ? 1 : null,
  usLowerOpticalPointSize: version >= kOS2Version5 ? 0 : null,
  usUpperOpticalPointSize: version >= kOS2Version5 ? 0xFFFE : null,
);

OS2Table _roundTrip(int version) {
  final table = _table(version);
  final bytes = ByteData(table.size);
  encodeOS2Table(table, bytes);

  return readOS2Table(
    bytes,
    TableRecordEntry('OS/2', 0, 0, bytes.lengthInBytes),
  );
}

void main() {
  group('readOS2Table', () {
    test('reads back the version-0 fields shared by every version', () {
      final decoded = _roundTrip(kOS2Version0);

      expect(decoded.version, kOS2Version0);
      expect(decoded.xAvgCharWidth, 500);
      expect(decoded.achVendID, 'PfPl');
      expect(decoded.usFirstCharIndex, 0xE001);
      expect(decoded.usLastCharIndex, 0xE0FF);
    });

    test('leaves version-1+ fields null for a version-0 table', () {
      final decoded = _roundTrip(kOS2Version0);

      expect(decoded.ulCodePageRange1, isNull);
      expect(decoded.sxHeight, isNull);
      expect(decoded.usLowerOpticalPointSize, isNull);
    });

    test('reads version-1 fields once the version declares them', () {
      final decoded = _roundTrip(kOS2Version1);

      expect(decoded.ulCodePageRange1, 1);
      expect(decoded.ulCodePageRange2, 0);
      expect(decoded.sxHeight, isNull);
    });

    test('reads version-4 fields once the version declares them', () {
      final decoded = _roundTrip(kOS2Version4);

      expect(decoded.sxHeight, 500);
      expect(decoded.sCapHeight, 700);
      expect(decoded.usLowerOpticalPointSize, isNull);
    });

    test('reads version-5 fields once the version declares them', () {
      final decoded = _roundTrip(kOS2Version5);

      expect(decoded.usLowerOpticalPointSize, 0);
      expect(decoded.usUpperOpticalPointSize, 0xFFFE);
    });

    test('reads the 10-byte PANOSE classification', () {
      final decoded = _roundTrip(kOS2Version5);

      expect(decoded.panose, [2, 0, 5, 3, 0, 0, 0, 0, 0, 0]);
    });
  });
}
