import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/font_tables.dart';
import 'package:fontify_plus/src/otf/otf.dart';
import 'package:fontify_plus/src/otf/table/all.dart';
import 'package:fontify_plus/src/utils/exception.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

OpenTypeFont _buildFont({bool useOpenType = true}) {
  final glyph = GenericGlyph.fromSvg(
    'icon',
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<path d="M0 0 L10 0 L10 10 Z"/></svg>',
  );

  return OpenTypeFont.createFromGlyphs(
    glyphList: [glyph],
    fontName: 'Test',
    useOpenType: useOpenType,
  );
}

void main() {
  group('FontTables.lookup', () {
    test('returns the table when the tag holds one of the asked-for type', () {
      final head = _buildFont().head;
      final tables = FontTables({kHeadTag: head});

      expect(tables.lookup<HeaderTable>(kHeadTag), same(head));
    });

    test('returns null when the tag is absent', () {
      final tables = FontTables({});

      expect(tables.lookup<HeaderTable>(kHeadTag), isNull);
    });

    test('returns null when the tag holds a different kind of table', () {
      // A head table filed under the glyf tag: corruption, not absence.
      final tables = FontTables({kGlyfTag: _buildFont().head});

      expect(tables.lookup<GlyphDataTable>(kGlyfTag), isNull);
    });
  });

  group('FontTables.require', () {
    test('returns the table when the tag holds one of the asked-for type', () {
      final head = _buildFont().head;
      final tables = FontTables({kHeadTag: head});

      expect(tables.require<HeaderTable>(kHeadTag), same(head));
    });

    test('throws naming the tag when it is absent', () {
      final tables = FontTables({});

      expect(
        () => tables.require<HeaderTable>(kHeadTag),
        throwsA(
          isA<TableDataFormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains(kHeadTag), contains('no')),
          ),
        ),
      );
    });

    test('reports a wrong-typed tag as a type mismatch, not as absent', () {
      final tables = FontTables({kGlyfTag: _buildFont().head});

      expect(
        () => tables.require<GlyphDataTable>(kGlyfTag),
        throwsA(
          isA<TableDataFormatException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains(kGlyfTag),
              contains('$GlyphDataTable'),
              isNot(contains('no "$kGlyfTag"')),
            ),
          ),
        ),
      );
    });
  });

  group('FontTables.asMap', () {
    test('exposes the tables by tag', () {
      final head = _buildFont().head;
      final tables = FontTables({kHeadTag: head});

      expect(tables.asMap, {kHeadTag: head});
    });

    test('rejects writes, because FontTables owns the map', () {
      final tables = FontTables({});

      expect(
        () => tables.asMap[kHeadTag] = _buildFont().head,
        throwsUnsupportedError,
      );
    });
  });

  group('OpenTypeFont format-dependent table getters', () {
    test('glyf and loca are null on a CFF font', () {
      final font = _buildFont();

      expect(font.glyf, isNull);
      expect(font.loca, isNull);
    });

    test('cff is present on a CFF font', () {
      final font = _buildFont();

      expect(font.cff, isNotNull);
      expect(font.cff2, isNull);
    });

    test('cff and cff2 are null on a TrueType font', () {
      final font = _buildFont(useOpenType: false);

      expect(font.cff, isNull);
      expect(font.cff2, isNull);
    });

    test('glyf and loca are present on a TrueType font', () {
      final font = _buildFont(useOpenType: false);

      expect(font.glyf?.glyphList, isNotEmpty);
      expect(font.loca?.glyphOffsets, isNotEmpty);
    });

    test('fvar and STAT are null on a font built without them', () {
      final font = _buildFont();

      expect(font.fvar, isNull);
      expect(font.stat, isNull);
    });
  });

  group('OpenTypeFont required table getters', () {
    test('name the missing tag rather than throwing a bare TypeError', () {
      // The offset table's numTables is irrelevant here and cannot be 0
      // (OffsetTable.create takes its log); what matters is the empty map.
      final font = OpenTypeFont(OffsetTable.create(1, true), {});

      expect(
        () => font.head,
        throwsA(
          isA<TableDataFormatException>().having(
            (e) => e.message,
            'message',
            contains(kHeadTag),
          ),
        ),
      );
    });
  });
}
