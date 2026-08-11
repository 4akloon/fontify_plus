import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/name/name_id.dart';
import 'package:fontify_plus/src/otf/table/name/naming_table_format0.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

/// The NameIDs this format's fixed default-string map always writes.
///
/// `NameID.values` also includes `strokeWidthAxis`, an `fvar`/`STAT` axis
/// name that `NamingTableFormat0.create` writes only when its optional
/// `axisName` parameter is given (see `naming_table_test.dart` for that
/// case). None of the calls in this file pass one, so it's excluded here
/// rather than asserted (incorrectly) to be present.
const _kStandardNameIds = [
  NameID.copyright,
  NameID.fontFamily,
  NameID.fontSubfamily,
  NameID.uniqueID,
  NameID.fullFontName,
  NameID.version,
  NameID.postScriptName,
  NameID.manufacturer,
  NameID.description,
  NameID.urlVendor,
];

void main() {
  group('NamingTableFormat0.create', () {
    test('familyName is the font name it was given', () {
      final table = NamingTableFormat0.create(
        'My Icons',
        null,
        const Revision(1, 0),
      );

      expect(table.familyName, 'My Icons');
    });

    test('writes every string once per platform template', () {
      final table = NamingTableFormat0.create(
        'My Icons',
        null,
        const Revision(1, 0),
      );

      // Written for 2 platform templates (Mac + Windows).
      expect(
        table.header.nameRecordList,
        hasLength(_kStandardNameIds.length * 2),
      );
    });

    test('uses the given description when provided', () {
      final table = NamingTableFormat0.create(
        'My Icons',
        'A custom description',
        const Revision(1, 0),
      );

      expect(
        table.getStringByNameId(NameID.description),
        'A custom description',
      );
    });

    test('falls back to a generated description when none is given', () {
      final table = NamingTableFormat0.create(
        'My Icons',
        null,
        const Revision(1, 0),
      );

      expect(table.getStringByNameId(NameID.description), isNotNull);
    });

    test('resolves every name ID this format writes', () {
      final table = NamingTableFormat0.create(
        'My Icons',
        null,
        const Revision(1, 0),
      );

      for (final id in _kStandardNameIds) {
        expect(table.getStringByNameId(id), isNotNull, reason: '$id');
      }
    });
  });

  group('NamingTableFormat0 round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final table = NamingTableFormat0.create(
        'My Icons',
        null,
        const Revision(1, 0),
      );
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      final decoded = NamingTableFormat0.fromByteData(
        bytes,
        TableRecordEntry(
          'name',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
      )!;

      expect(decoded.familyName, 'My Icons');
      expect(decoded.getStringByNameId(NameID.version), contains('1.0'));
    });
  });
}
