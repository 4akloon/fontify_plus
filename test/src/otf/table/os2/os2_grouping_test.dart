import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/os2/os2_encoder.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_reader.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_table.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_version.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_version_fields.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

const _version0 = OS2Version0Fields(
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
);

const _version1 = OS2Version1Fields(ulCodePageRange1: 1, ulCodePageRange2: 0);

const _version4 = OS2Version4Fields(
  sxHeight: 500,
  sCapHeight: 700,
  usDefaultChar: 32,
  usBreakChar: 32,
  usMaxContext: 1,
);

const _version5 = OS2Version5Fields(
  usLowerOpticalPointSize: 0,
  usUpperOpticalPointSize: 0xFFFE,
);

OS2Table _table(int version) => OS2Table(
  null,
  version: version,
  version0: _version0,
  version1: version >= kOS2Version1 ? _version1 : null,
  version4: version >= kOS2Version4 ? _version4 : null,
  version5: version >= kOS2Version5 ? _version5 : null,
);

Uint8List _encode(OS2Table table) {
  final bytes = ByteData(table.size);
  encodeOS2Table(table, bytes);

  return bytes.buffer.asUint8List();
}

OS2Table _read(Uint8List bytes) => readOS2Table(
  ByteData.sublistView(bytes),
  TableRecordEntry('OS/2', 0, 0, bytes.lengthInBytes),
);

void main() {
  group('OS2Table version groups', () {
    test('a version-0 table carries no group above version 0', () {
      final table = _table(kOS2Version0);

      expect(table.version0.achVendID, 'PfPl');
      expect(table.version1, isNull);
      expect(table.version4, isNull);
      expect(table.version5, isNull);
    });

    test('a version-1 table carries the version-1 group and no higher', () {
      final table = _table(kOS2Version1);

      expect(table.version1?.ulCodePageRange1, 1);
      expect(table.version4, isNull);
      expect(table.version5, isNull);
    });

    test('a version-4 table carries every group up to version 4', () {
      final table = _table(kOS2Version4);

      expect(table.version1, isNotNull);
      expect(table.version4?.sxHeight, 500);
      expect(table.version5, isNull);
    });

    test('a version-5 table carries every group', () {
      final table = _table(kOS2Version5);

      expect(table.version1, isNotNull);
      expect(table.version4, isNotNull);
      expect(table.version5?.usUpperOpticalPointSize, 0xFFFE);
    });
  });

  group('OS2Table.size follows the groups present', () {
    test('is 78 bytes with only the version-0 group', () {
      expect(_table(kOS2Version0).size, 78);
    });

    test('is 86 bytes with the version-1 group', () {
      expect(_table(kOS2Version1).size, 86);
    });

    test('is 96 bytes with the version-4 group', () {
      expect(_table(kOS2Version4).size, 96);
    });

    test('is 100 bytes with the version-5 group', () {
      expect(_table(kOS2Version5).size, 100);
    });
  });

  group('byte round trip', () {
    for (final version in const [
      kOS2Version0,
      kOS2Version1,
      kOS2Version4,
      kOS2Version5,
    ]) {
      test('bytes survive read then encode at version $version', () {
        final original = _encode(_table(version));
        final reEncoded = _encode(_read(original));

        expect(reEncoded, orderedEquals(original));
      });
    }
  });

  group('a version the group set cannot name', () {
    // OpenType version 3 adds no fields over version 2, and this package's
    // kOS2VersionDataSize has no entry for either, so a version-3 table is
    // read with the version-1 group and nothing above it. Its version is
    // therefore not recoverable from which groups are present — which is
    // why OS2Table stores it rather than deriving it.
    Uint8List versionThreeBytes() {
      final bytes = _encode(_table(kOS2Version1));
      ByteData.sublistView(bytes).setInt16(0, 3);

      return bytes;
    }

    test('a version-3 table keeps its declared version through a read', () {
      final decoded = _read(versionThreeBytes());

      expect(decoded.version, 3);
      expect(decoded.version1, isNotNull);
      expect(decoded.version4, isNull);
    });

    test('re-encoding a version-3 table writes 3 back, not 1', () {
      final original = versionThreeBytes();

      expect(_encode(_read(original)), orderedEquals(original));
    });
  });
}
