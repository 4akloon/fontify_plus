import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/os2/os2_encoder.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_reader.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_table.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_version.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_version_fields.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:fontify_plus/src/utils/exception.dart';
import 'package:test/test.dart';

/// Every numeric field below holds a value no other field holds.
///
/// That is the property that makes the round trip injective. With realistic
/// values — `ulUnicodeRange2/3/4` all zero, `usDefaultChar` and `usBreakChar`
/// both 32, `sTypoAscender` and `usWinAscent` both 800 — a reader or encoder
/// that swapped two fields within one of those sets would produce identical
/// bytes and identical decoded values, and every test here would still pass.
/// Distinctness is load-bearing: do not "tidy" these into plausible metrics.
const _version5 = OS2Version5Fields(
  usLowerOpticalPointSize: 35,
  usUpperOpticalPointSize: 65534,
);

const _version4 = OS2Version4Fields(
  sxHeight: 502,
  sCapHeight: 702,
  usDefaultChar: 33,
  usBreakChar: 34,
  usMaxContext: 3,
  version5: _version5,
);

const _version4WithoutV5 = OS2Version4Fields(
  sxHeight: 502,
  sCapHeight: 702,
  usDefaultChar: 33,
  usBreakChar: 34,
  usMaxContext: 3,
);

const _version1 = OS2Version1Fields(
  ulCodePageRange1: 0x50000005,
  ulCodePageRange2: 0x60000006,
  version4: _version4,
);

const _version0 = OS2Version0Fields(
  xAvgCharWidth: 501,
  usWeightClass: 402,
  usWidthClass: 7,
  fsType: 8,
  ySubscriptXSize: 651,
  ySubscriptYSize: 602,
  ySubscriptXOffset: 13,
  ySubscriptYOffset: 141,
  ySuperscriptXSize: 653,
  ySuperscriptYSize: 604,
  ySuperscriptXOffset: 15,
  ySuperscriptYOffset: 481,
  yStrikeoutSize: 101,
  yStrikeoutPosition: 261,
  sFamilyClass: 262,
  panose: [2, 1, 5, 3, 4, 6, 7, 8, 9, 10],
  ulUnicodeRange1: 0x10000001,
  ulUnicodeRange2: 0x20000002,
  ulUnicodeRange3: 0x30000003,
  ulUnicodeRange4: 0x40000004,
  achVendID: 'PfPl',
  fsSelection: 65,
  usFirstCharIndex: 57345,
  usLastCharIndex: 57599,
  sTypoAscender: 801,
  sTypoDescender: -201,
  sTypoLineGap: 91,
  usWinAscent: 802,
  usWinDescent: 203,
);

/// The groups a table of [version] carries, nested the way the format nests.
OS2Version1Fields? _groupsFor(int version) {
  if (version < kOS2Version1) {
    return null;
  }

  if (version < kOS2Version4) {
    return const OS2Version1Fields(
      ulCodePageRange1: 0x50000005,
      ulCodePageRange2: 0x60000006,
    );
  }

  if (version < kOS2Version5) {
    return const OS2Version1Fields(
      ulCodePageRange1: 0x50000005,
      ulCodePageRange2: 0x60000006,
      version4: _version4WithoutV5,
    );
  }

  return _version1;
}

OS2Table _table(int version) => OS2Table(
  null,
  version: version,
  version0: _version0,
  version1: _groupsFor(version),
);

/// Every field of [table], keyed by name.
///
/// Comparing two of these compares all 36 numeric fields plus `panose` and
/// `achVendID` in one assertion, and names the offender on failure. A
/// field-by-field comparison catches what a byte comparison cannot: an
/// encoder that writes two fields to the *same* offset round-trips its own
/// bytes perfectly, but loses a value.
Map<String, Object?> _fields(OS2Table table) => {
  'version': table.version,
  'xAvgCharWidth': table.version0.xAvgCharWidth,
  'usWeightClass': table.version0.usWeightClass,
  'usWidthClass': table.version0.usWidthClass,
  'fsType': table.version0.fsType,
  'ySubscriptXSize': table.version0.ySubscriptXSize,
  'ySubscriptYSize': table.version0.ySubscriptYSize,
  'ySubscriptXOffset': table.version0.ySubscriptXOffset,
  'ySubscriptYOffset': table.version0.ySubscriptYOffset,
  'ySuperscriptXSize': table.version0.ySuperscriptXSize,
  'ySuperscriptYSize': table.version0.ySuperscriptYSize,
  'ySuperscriptXOffset': table.version0.ySuperscriptXOffset,
  'ySuperscriptYOffset': table.version0.ySuperscriptYOffset,
  'yStrikeoutSize': table.version0.yStrikeoutSize,
  'yStrikeoutPosition': table.version0.yStrikeoutPosition,
  'sFamilyClass': table.version0.sFamilyClass,
  'panose': table.version0.panose,
  'ulUnicodeRange1': table.version0.ulUnicodeRange1,
  'ulUnicodeRange2': table.version0.ulUnicodeRange2,
  'ulUnicodeRange3': table.version0.ulUnicodeRange3,
  'ulUnicodeRange4': table.version0.ulUnicodeRange4,
  'achVendID': table.version0.achVendID,
  'fsSelection': table.version0.fsSelection,
  'usFirstCharIndex': table.version0.usFirstCharIndex,
  'usLastCharIndex': table.version0.usLastCharIndex,
  'sTypoAscender': table.version0.sTypoAscender,
  'sTypoDescender': table.version0.sTypoDescender,
  'sTypoLineGap': table.version0.sTypoLineGap,
  'usWinAscent': table.version0.usWinAscent,
  'usWinDescent': table.version0.usWinDescent,
  'ulCodePageRange1': table.version1?.ulCodePageRange1,
  'ulCodePageRange2': table.version1?.ulCodePageRange2,
  'sxHeight': table.version4?.sxHeight,
  'sCapHeight': table.version4?.sCapHeight,
  'usDefaultChar': table.version4?.usDefaultChar,
  'usBreakChar': table.version4?.usBreakChar,
  'usMaxContext': table.version4?.usMaxContext,
  'usLowerOpticalPointSize': table.version5?.usLowerOpticalPointSize,
  'usUpperOpticalPointSize': table.version5?.usUpperOpticalPointSize,
};

Uint8List _encode(OS2Table table) {
  final bytes = ByteData(table.size);
  encodeOS2Table(table, bytes);

  return bytes.buffer.asUint8List();
}

OS2Table _read(Uint8List bytes) => readOS2Table(
  ByteData.sublistView(bytes),
  TableRecordEntry('OS/2', checkSum: 0, offset: 0, length: bytes.lengthInBytes),
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

      expect(table.version1?.ulCodePageRange1, 0x50000005);
      expect(table.version4, isNull);
      expect(table.version5, isNull);
    });

    test('a version-4 table carries every group up to version 4', () {
      final table = _table(kOS2Version4);

      expect(table.version1, isNotNull);
      expect(table.version4?.sxHeight, 502);
      expect(table.version5, isNull);
    });

    test('a version-5 table carries every group', () {
      final table = _table(kOS2Version5);

      expect(table.version1, isNotNull);
      expect(table.version4, isNotNull);
      expect(table.version5?.usUpperOpticalPointSize, 65534);
    });

    test('the higher groups are reached only through the version-1 group', () {
      // The compile-time half of the guarantee cannot be asserted at run
      // time: `version4` has no home outside an `OS2Version1Fields`, so a
      // table with `sxHeight` but no `ulCodePageRange1` does not type-check.
      // What is checkable is that the shorthand getters agree with the
      // nesting they read through.
      final table = _table(kOS2Version5);

      expect(table.version4, same(table.version1?.version4));
      expect(table.version5, same(table.version1?.version4?.version5));
      expect(_table(kOS2Version0).version4, isNull);
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

  group('round trip', () {
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

      test('every field survives encode then read at version $version', () {
        final original = _table(version);

        expect(_fields(_read(_encode(original))), _fields(original));
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

  group('a version that disagrees with its groups', () {
    // These throw rather than assert, so they hold in a release build too --
    // which is the point. The encoder used to force-unwrap every optional
    // field, so a version-5 table missing its version-5 group crashed
    // immediately; grouping must not turn that crash into a 96-byte table
    // whose version field claims 100 bytes of content.
    test('version 5 without the version-5 group is rejected', () {
      expect(
        () => OS2Table(
          null,
          version: kOS2Version5,
          version0: _version0,
          version1: const OS2Version1Fields(
            ulCodePageRange1: 0x50000005,
            ulCodePageRange2: 0x60000006,
            version4: _version4WithoutV5,
          ),
        ),
        throwsA(isA<TableDataFormatException>()),
      );
    });

    test('version 1 without the version-1 group is rejected', () {
      expect(
        () => OS2Table(null, version: kOS2Version1, version0: _version0),
        throwsA(isA<TableDataFormatException>()),
      );
    });

    test('version 0 carrying a version-1 group is rejected', () {
      expect(
        () => OS2Table(
          null,
          version: kOS2Version0,
          version0: _version0,
          version1: const OS2Version1Fields(
            ulCodePageRange1: 0x50000005,
            ulCodePageRange2: 0x60000006,
          ),
        ),
        throwsA(isA<TableDataFormatException>()),
      );
    });

    test('the message names the group that is out of step', () {
      expect(
        () => OS2Table(null, version: kOS2Version4, version0: _version0),
        throwsA(
          isA<TableDataFormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('version 4'), contains('version-1 group')),
          ),
        ),
      );
    });
  });
}
