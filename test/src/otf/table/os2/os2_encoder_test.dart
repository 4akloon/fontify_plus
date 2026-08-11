import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/os2/os2_encoder.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_table.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_version.dart';
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

void main() {
  group('encodeOS2Table', () {
    test('writes the version-0 fields shared by every version', () {
      final table = _table(kOS2Version0);
      final bytes = ByteData(table.size);

      encodeOS2Table(table, bytes);

      expect(bytes.getInt16(0), kOS2Version0);
      expect(bytes.getInt16(2), 500);
      expect(bytes.getUint16(4), 400);
    });

    test('writes achVendID as a 4-character tag', () {
      final table = _table(kOS2Version0);
      final bytes = ByteData(table.size);

      encodeOS2Table(table, bytes);

      final tag = String.fromCharCodes(
        List.generate(4, (i) => bytes.getUint8(58 + i)),
      );
      expect(tag, 'PfPl');
    });

    test('does not write version-1 fields for a version-0 table', () {
      final table = _table(kOS2Version0);
      final bytes = ByteData(table.size);

      expect(bytes.lengthInBytes, 78);
      expect(() => encodeOS2Table(table, bytes), returnsNormally);
    });

    test('writes version-1 fields once the version allows them', () {
      final table = _table(kOS2Version1);
      final bytes = ByteData(table.size);

      encodeOS2Table(table, bytes);

      expect(bytes.getUint32(78), 1);
      expect(bytes.getUint32(82), 0);
    });

    test('writes version-4 fields once the version allows them', () {
      final table = _table(kOS2Version4);
      final bytes = ByteData(table.size);

      encodeOS2Table(table, bytes);

      expect(bytes.getInt16(86), 500);
      expect(bytes.getInt16(88), 700);
    });

    test('writes version-5 fields once the version allows them', () {
      final table = _table(kOS2Version5);
      final bytes = ByteData(table.size);

      encodeOS2Table(table, bytes);

      expect(bytes.getUint16(96), 0);
      expect(bytes.getUint16(98), 0xFFFE);
    });
  });
}
