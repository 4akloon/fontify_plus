import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/os2/os2_encoder.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_reader.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_table.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_version.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

OS2Table _table(int version) => OS2Table(
  null,
  version,
  500,
  400,
  5,
  0,
  650,
  600,
  0,
  140,
  650,
  600,
  0,
  480,
  100,
  260,
  0,
  [2, 0, 5, 3, 0, 0, 0, 0, 0, 0],
  1,
  0,
  0,
  0,
  'PfPl',
  0x40,
  0xE001,
  0xE0FF,
  800,
  -200,
  0,
  800,
  200,
  version >= kOS2Version1 ? 1 : null,
  version >= kOS2Version1 ? 0 : null,
  version >= kOS2Version4 ? 500 : null,
  version >= kOS2Version4 ? 700 : null,
  version >= kOS2Version4 ? 32 : null,
  version >= kOS2Version4 ? 32 : null,
  version >= kOS2Version4 ? 1 : null,
  version >= kOS2Version5 ? 0 : null,
  version >= kOS2Version5 ? 0xFFFE : null,
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
