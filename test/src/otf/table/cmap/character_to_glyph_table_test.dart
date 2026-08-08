import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/table/cmap/character_to_glyph_table.dart';
import 'package:fontify_plus/src/otf/table/cmap/cmap_segment_mapping_table.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

GenericGlyph glyphWithCode(int? charCode) {
  final glyph = GenericGlyph.empty();
  glyph.metadata.charCode = charCode;

  return glyph;
}

void main() {
  group('CharacterToGlyphTable.create', () {
    test('skips .notdef when building segments', () {
      // .notdef (index 0) never has a char code of its own; if it were not
      // skipped, glyph 0 would incorrectly claim the first real char code.
      final table = CharacterToGlyphTable.create([
        glyphWithCode(null),
        glyphWithCode(0xE000),
      ]);

      final format4 =
          table.data.whereType<CmapSegmentMappingToDeltaValuesTable>().first;

      expect(format4.startCode, contains(0xE000));
    });

    test('writes five subtables by default', () {
      final table = CharacterToGlyphTable.create([
        glyphWithCode(null),
        glyphWithCode(0xE000),
      ]);

      expect(table.data, hasLength(5));
    });

    test('the format 4 subtable ends with the required 0xFFFF sentinel', () {
      final table = CharacterToGlyphTable.create([
        glyphWithCode(null),
        glyphWithCode(0xE000),
      ]);

      final format4 =
          table.data.whereType<CmapSegmentMappingToDeltaValuesTable>().first;

      expect(format4.startCode.last, 0xFFFF);
      expect(format4.endCode.last, 0xFFFF);
    });
  });

  group('CharacterToGlyphTable round trip', () {
    test('round-trips through encodeToBinary and fromByteData', () {
      final table = CharacterToGlyphTable.create([
        glyphWithCode(null),
        glyphWithCode(0xE000),
        glyphWithCode(0xE001),
      ]);
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      final decoded = CharacterToGlyphTable.fromByteData(
        bytes,
        TableRecordEntry('cmap', 0, 0, bytes.lengthInBytes),
      );

      expect(decoded.data, hasLength(table.data.length));
    });
  });
}
