import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/table/all.dart';
import 'package:fontify_plus/src/svg/svg.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

GenericGlyph triangleGlyph() {
  final svg = Svg.parse(
    'icon',
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<path d="M0 0 L10 0 L10 10 Z"/></svg>',
  );

  return GenericGlyph.fromSvg(svg);
}

void main() {
  group('CFF2Table.create', () {
    test('stores exactly one charstring per glyph, with no defaults added', () {
      // Unlike CFF1 (via the font builder), CFF2Table.create takes the glyph
      // list as given — no implicit .notdef/space are added here.
      final table = CFF2Table.create([triangleGlyph(), triangleGlyph()]);

      expect(table.charStringsData.data, hasLength(2));
    });

    test('omits variation data when none is given', () {
      final table = CFF2Table.create([triangleGlyph()]);

      expect(table.vstoreData, isNull);
    });

    test('a Private DICT is present even though it is empty', () {
      final table = CFF2Table.create([triangleGlyph()]);

      expect(table.privateDictList, hasLength(1));
    });

    test('produces a table whose declared size matches its encoded length', () {
      final table = CFF2Table.create([triangleGlyph()]);

      expect(() => table.encodeToBinary(ByteData(table.size)), returnsNormally);
    });

    test('round-trips through fromByteData', () {
      final table = CFF2Table.create([triangleGlyph(), triangleGlyph()]);
      final bytes = ByteData(table.size);

      table.encodeToBinary(bytes);

      final decoded = CFF2Table.fromByteData(
        bytes,
        TableRecordEntry(kCFF2Tag, 0, 0, bytes.lengthInBytes),
      );

      expect(decoded.charStringsData.data, hasLength(2));
    });

    test('recalculateOffsets can run more than once without breaking size', () {
      // The real font-write path calls recalculateOffsets, then measures
      // size, then encodes — recalculating twice must not drift.
      final table = CFF2Table.create([triangleGlyph()]);
      final sizeBefore = table.size;

      table.recalculateOffsets();

      expect(table.size, sizeBefore);
    });
  });
}
