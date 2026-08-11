import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/table/post/post_script_data.dart';
import 'package:fontify_plus/src/otf/table/post/post_script_table.dart';
import 'package:fontify_plus/src/otf/table/post/post_script_version_20.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:test/test.dart';

GenericGlyph _namedGlyph(String name) =>
    GenericGlyph.empty()..metadata.name = name;

void main() {
  group('PostScriptTable.create', () {
    test('usePostV2 = false produces a version 3.0 table with no names', () {
      final table = PostScriptTable.create([_namedGlyph('glyph_one')], false);

      expect(table.data, isA<PostScriptVersion30>());
    });

    test(
      'usePostV2 = true produces a version 2.0 table with the given names',
      () {
        final table = PostScriptTable.create([_namedGlyph('glyph_one')], true);

        final data = table.data as PostScriptVersion20;
        expect(data.glyphNames.single.string, 'glyph_one');
      },
    );

    test('usePostV2 = true treats a missing glyph name as an empty string', () {
      final table = PostScriptTable.create([GenericGlyph.empty()], true);

      final data = table.data as PostScriptVersion20;
      expect(data.glyphNames.single.string, '');
    });
  });

  group('PostScriptTable round trip', () {
    test(
      'round-trips a version 3.0 table through encodeToBinary and fromByteData',
      () {
        final table = PostScriptTable.create([_namedGlyph('glyph_one')], false);
        final bytes = ByteData(table.size);

        table.encodeToBinary(bytes);

        final decoded = PostScriptTable.fromByteData(
          bytes,
          TableRecordEntry(
            'post',
            checkSum: 0,
            offset: 0,
            length: bytes.lengthInBytes,
          ),
        );

        expect(decoded.data, isA<PostScriptVersion30>());
      },
    );

    test(
      'round-trips a version 2.0 table through encodeToBinary and fromByteData',
      () {
        final table = PostScriptTable.create([_namedGlyph('glyph_one')], true);
        final bytes = ByteData(table.size);

        table.encodeToBinary(bytes);

        final decoded = PostScriptTable.fromByteData(
          bytes,
          TableRecordEntry(
            'post',
            checkSum: 0,
            offset: 0,
            length: bytes.lengthInBytes,
          ),
        );

        final data = decoded.data as PostScriptVersion20;
        expect(data.glyphNames.single.string, 'glyph_one');
      },
    );
  });
}
