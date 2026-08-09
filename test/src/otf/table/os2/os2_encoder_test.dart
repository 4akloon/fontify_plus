import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/os2/os2_encoder.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_table.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_version.dart';
import 'package:test/test.dart';

OS2Table _table(int version) => OS2Table(
  null,
  version,
  500, // xAvgCharWidth
  400, // usWeightClass
  5, // usWidthClass
  0, // fsType
  650, // ySubscriptXSize
  600, // ySubscriptYSize
  0, // ySubscriptXOffset
  140, // ySubscriptYOffset
  650, // ySuperscriptXSize
  600, // ySuperscriptYSize
  0, // ySuperscriptXOffset
  480, // ySuperscriptYOffset
  100, // yStrikeoutSize
  260, // yStrikeoutPosition
  0, // sFamilyClass
  [2, 0, 5, 3, 0, 0, 0, 0, 0, 0], // panose
  1, // ulUnicodeRange1
  0, // ulUnicodeRange2
  0, // ulUnicodeRange3
  0, // ulUnicodeRange4
  'PfPl', // achVendID
  0x40, // fsSelection
  0xE001, // usFirstCharIndex
  0xE0FF, // usLastCharIndex
  800, // sTypoAscender
  -200, // sTypoDescender
  0, // sTypoLineGap
  800, // usWinAscent
  200, // usWinDescent
  version >= kOS2Version1 ? 1 : null, // ulCodePageRange1
  version >= kOS2Version1 ? 0 : null, // ulCodePageRange2
  version >= kOS2Version4 ? 500 : null, // sxHeight
  version >= kOS2Version4 ? 700 : null, // sCapHeight
  version >= kOS2Version4 ? 32 : null, // usDefaultChar
  version >= kOS2Version4 ? 32 : null, // usBreakChar
  version >= kOS2Version4 ? 1 : null, // usMaxContext
  version >= kOS2Version5 ? 0 : null, // usLowerOpticalPointSize
  version >= kOS2Version5 ? 0xFFFE : null, // usUpperOpticalPointSize
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
