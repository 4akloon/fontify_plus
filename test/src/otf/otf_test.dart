import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/otf.dart';
import 'package:fontify_plus/src/otf/table/offset.dart';
import 'package:fontify_plus/src/otf/table/table_record_entry.dart';
import 'package:fontify_plus/src/svg/svg.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

OpenTypeFont _buildFont({bool useOpenType = true}) {
  final svg = Svg.parse(
    'icon',
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<path d="M0 0 L10 0 L10 10 Z"/></svg>',
  );

  return OpenTypeFont.createFromGlyphs(
    glyphList: [GenericGlyph.fromSvg(svg)],
    fontName: 'Test',
    useOpenType: useOpenType,
  );
}

void main() {
  group('OpenTypeFont.createFromGlyphs', () {
    test('delegates to OpenTypeFontBuilder', () {
      final font = _buildFont();

      expect(font.familyName, 'Test');
    });
  });

  group('OpenTypeFont table getters', () {
    test('resolve to their concrete table types for an OpenType (CFF) font',
        () {
      final font = _buildFont();

      expect(font.head.unitsPerEm, isPositive);
      expect(font.maxp.numGlyphs, isPositive);
      expect(font.hhea.ascender, isPositive);
      expect(font.hmtx.hMetrics, isNotEmpty);
      expect(font.name.familyName, 'Test');
      expect(font.cmap.data, isNotEmpty);
      expect(font.gsub.lookupListTable.lookupTables, isNotEmpty);
      expect(font.os2.achVendID, isNotEmpty);
      expect(font.post.header.version.major, isNonNegative);
      expect(font.cff.charStringsData.data, isNotEmpty);
    });

    test('glyf throws when the font has no glyf table (OpenType/CFF)', () {
      final font = _buildFont();

      expect(() => font.glyf, throwsA(isA<TypeError>()));
    });

    test('resolves glyf/loca for a TrueType font', () {
      final font = _buildFont(useOpenType: false);

      expect(font.glyf.glyphList, isNotEmpty);
      expect(font.loca.glyphOffsets, isNotEmpty);
    });
  });

  group('OpenTypeFont.isOpenType', () {
    test('is true for a CFF-outline font', () {
      expect(_buildFont().isOpenType, isTrue);
    });

    test('is false for a TrueType-outline font', () {
      expect(_buildFont(useOpenType: false).isOpenType, isFalse);
    });
  });

  group('OpenTypeFont.size', () {
    test(
        'is the offset table plus every directory entry plus every padded table',
        () {
      final font = _buildFont();

      final expectedTableListSize = font.tableMap.values
          .fold<int>(0, (p, t) => p + getPaddedTableSize(t.size));

      expect(
        font.size,
        kOffsetTableLength +
            kTableRecordEntryLength * font.tableMap.length +
            expectedTableListSize,
      );
    });
  });

  group('OpenTypeFont.encodeToBinary', () {
    test('writes the table directory in ascending tag order', () {
      final font = _buildFont();
      final bytes = ByteData(font.size);

      font.encodeToBinary(bytes);

      final tags = [
        for (var i = 0; i < font.tableMap.length; i++)
          TableRecordEntry.fromByteData(
            bytes,
            kOffsetTableLength + i * kTableRecordEntryLength,
          ).tag,
      ];

      expect(tags, [...tags]..sort());
    });

    test('sets every table entry\'s offset once encoded', () {
      final font = _buildFont();
      final bytes = ByteData(font.size);

      font.encodeToBinary(bytes);

      for (final table in font.tableMap.values) {
        expect(table.entry, isNotNull);
      }
    });
  });

  group('OpenTypeFont.fromByteData', () {
    test('round-trips through a freshly encoded font', () {
      final font = _buildFont();
      final bytes = ByteData(font.size);
      font.encodeToBinary(bytes);

      final decoded = OpenTypeFont.fromByteData(bytes);

      expect(decoded.familyName, 'Test');
    });
  });
}
