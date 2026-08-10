import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/name/name_id.dart';
import 'package:fontify_plus/src/otf/table/name/naming_table_format0.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

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

      // 10 NameIDs, written for 2 platform templates (Mac + Windows).
      expect(table.header.nameRecordList, hasLength(20));
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

      for (final id in NameID.values) {
        // strokeWidthAxis is a `fvar` axis name: it is written into the
        // `name` table once `fvar` is wired into the font builder, not by
        // this format's fixed set of default strings.
        if (id == NameID.strokeWidthAxis) {
          continue;
        }

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
        TableRecordEntry('name', 0, 0, bytes.lengthInBytes),
      )!;

      expect(decoded.familyName, 'My Icons');
      expect(decoded.getStringByNameId(NameID.version), contains('1.0'));
    });
  });
}
