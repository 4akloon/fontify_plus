import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/otf.dart';
import 'package:fontify_plus/src/otf/table/all.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

GenericGlyph _triangleGlyph() => GenericGlyph.fromSvg(
  'icon',
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
      '<path d="M0 0 L10 0 L10 10 Z"/></svg>',
);

/// A real, fully-wired CFF1Table, built the way the font builder does.
CFF1Table buildCff1Table({int glyphCount = 1}) {
  final font = OpenTypeFont.createFromGlyphs(
    glyphList: [for (var i = 0; i < glyphCount; i++) _triangleGlyph()],
    fontName: 'Test',
  );

  // `font.cff` is nullable — a TrueType font has no CFF table at all — but
  // this one was just built with the default CFF outlines, so `require` both
  // states that and names the tag if the default ever changes.
  return font.tables.require<CFF1Table>(kCFFTag);
}

void main() {
  group('CFF1Table.create', () {
    test('produces a table whose declared size matches its encoded length', () {
      final table = buildCff1Table();
      table.recalculateOffsets();

      expect(() => table.encodeToBinary(ByteData(table.size)), returnsNormally);
    });

    test('round-trips through fromByteData', () {
      final table = buildCff1Table();
      table.recalculateOffsets();

      final bytes = ByteData(table.size);
      table.encodeToBinary(bytes);

      // fromByteData needs a TableRecordEntry; reuse a zero-offset one since
      // the bytes above start at the table's own beginning.
      final decoded = CFF1Table.fromByteData(
        bytes,
        TableRecordEntry(
          kCFFTag,
          checkSum: 0,
          offset: 0,
          length: bytes.lengthInBytes,
        ),
      );

      // .notdef, space, and the one requested glyph.
      expect(decoded.charStringsData.data, hasLength(3));
    });

    test('stores one charstring per glyph, including the built-in ones', () {
      final table = buildCff1Table(glyphCount: 3);

      // .notdef, space, and the three requested glyphs.
      expect(table.charStringsData.data, hasLength(5));
    });

    test('topDict is the first (and only) Top DICT', () {
      final table = buildCff1Table();

      expect(table.topDict, table.topDicts.data.first);
    });
  });
}
