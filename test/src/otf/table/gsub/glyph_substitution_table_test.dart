import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/gsub/glyph_substitution_table.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

void main() {
  group('GlyphSubstitutionTable.create', () {
    test('declares the default script, feature and lookup lists', () {
      final table = GlyphSubstitutionTable.create();

      expect(
        table.scriptListTable.scriptRecords.map((r) => r.scriptTag),
        ['DFLT', 'latn'],
      );
      expect(table.featureListTable.featureRecords.single.featureTag, 'liga');
      expect(table.lookupListTable.lookupTables.single.lookupType, 4);
    });
  });

  group('GlyphSubstitutionTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final table = GlyphSubstitutionTable.create();
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      final decoded = GlyphSubstitutionTable.fromByteData(
        bytes,
        TableRecordEntry(
          'GSUB',
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
      );

      expect(
        decoded.scriptListTable.scriptRecords.map((r) => r.scriptTag),
        ['DFLT', 'latn'],
      );
      expect(
        decoded.featureListTable.featureRecords.single.featureTag,
        'liga',
      );
      expect(decoded.lookupListTable.lookupTables.single.lookupType, 4);
    });

    test('fills in header offsets while encoding', () {
      final table = GlyphSubstitutionTable.create();
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      expect(table.header.scriptListOffset, table.header.size);
    });
  });
}
