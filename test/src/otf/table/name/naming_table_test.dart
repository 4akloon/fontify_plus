import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/name/name_id.dart';
import 'package:fontify_plus/src/otf/table/name/naming_table.dart';
import 'package:fontify_plus/src/otf/table/name/naming_table_format0.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

void main() {
  group('NamingTable.create', () {
    test('format 0 dispatches to NamingTableFormat0', () {
      expect(
        NamingTable.create('My Icons', null, const Revision(1, 0)),
        isA<NamingTableFormat0>(),
      );
    });

    test('returns null for an unsupported format', () {
      expect(
        NamingTable.create('My Icons', null, const Revision(1, 0), format: 99),
        isNull,
      );
    });

    test('no axis name record without an axis', () {
      final table = NamingTable.create('Test', null, const Revision(1, 0))!;

      expect(table.getStringByNameId(NameID.strokeWidthAxis), isNull);
    });

    test('the axis name is written once per platform template', () {
      // OTS validates fvar's axisNameID and every STAT valueNameID against
      // the name table and rejects the font if the string is missing.
      final table =
          NamingTable.create(
                'Test',
                null,
                const Revision(1, 0),
                axisName: 'Stroke Width',
              )!
              as NamingTableFormat0;

      expect(table.getStringByNameId(NameID.strokeWidthAxis), 'Stroke Width');
      expect(
        table.header.nameRecordList.where((r) => r.nameID == 256).length,
        2,
      );
    });

    test('records stay in ascending nameID order within a platform', () {
      final table =
          NamingTable.create(
                'Test',
                null,
                const Revision(1, 0),
                axisName: 'Stroke Width',
              )!
              as NamingTableFormat0;

      for (final platform in {
        for (final r in table.header.nameRecordList) r.platformID,
      }) {
        final ids = [
          for (final r in table.header.nameRecordList)
            if (r.platformID == platform) r.nameID,
        ];

        expect(ids, orderedEquals([...ids]..sort()));
      }
    });
  });

  group('NamingTable.fromByteData', () {
    test('format 0 dispatches to NamingTableFormat0', () {
      final built = NamingTableFormat0.create(
        'My Icons',
        null,
        const Revision(1, 0),
      );
      final bytes = ByteData(built.size);
      built.encodeToBinary(bytes);

      final decoded = NamingTable.fromByteData(
        bytes,
        TableRecordEntry('name', 0, 0, bytes.lengthInBytes),
      );

      expect(decoded, isA<NamingTableFormat0>());
    });

    test('returns null for an unsupported format', () {
      final bytes = ByteData(6)..setUint16(0, 99);

      expect(
        NamingTable.fromByteData(
          bytes,
          TableRecordEntry('name', 0, 0, bytes.lengthInBytes),
        ),
        isNull,
      );
    });
  });
}
