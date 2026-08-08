import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/table/cmap.dart';
import 'package:fontify_plus/src/otf/table/gsub.dart';
import 'package:fontify_plus/src/otf/table/head.dart';
import 'package:fontify_plus/src/otf/table/hhea.dart';
import 'package:fontify_plus/src/otf/table/hmtx.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_builder.dart';
import 'package:fontify_plus/src/otf/table/os2/os2_version.dart';
import 'package:fontify_plus/src/utils/exception.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

const _kUnitsPerEm = 1000;

List<GenericGlyphMetrics> _metricsList() => [
  GenericGlyphMetrics.empty(), // .notdef
  GenericGlyphMetrics(0, 700, 0, 800), // one icon glyph
];

List<GenericGlyph> _fullGlyphList() => [
  GenericGlyph.empty(), // .notdef, no charCode
  GenericGlyph.empty()..metadata.charCode = 0xE001,
];

HorizontalMetricsTable _hmtx() =>
    HorizontalMetricsTable.create(_metricsList(), _kUnitsPerEm);

HeaderTable _head() => HeaderTable.create(
  _metricsList(),
  null,
  const Revision(1, 0),
  _kUnitsPerEm,
);

HorizontalHeaderTable _hhea(HorizontalMetricsTable hmtx) =>
    HorizontalHeaderTable.create(_metricsList(), hmtx, 800, -200);

CharacterToGlyphTable _cmap() => CharacterToGlyphTable.create(_fullGlyphList());

void main() {
  group('buildOS2Table', () {
    test('throws when achVendID is not exactly 4 ASCII characters', () {
      final hmtx = _hmtx();

      expect(
        () => buildOS2Table(
          hmtx,
          _head(),
          _hhea(hmtx),
          _cmap(),
          GlyphSubstitutionTable.create(),
          'TooLong',
        ),
        throwsA(isA<TableDataFormatException>()),
      );
    });

    test('carries the given achVendID and version through', () {
      final hmtx = _hmtx();

      final table = buildOS2Table(
        hmtx,
        _head(),
        _hhea(hmtx),
        _cmap(),
        GlyphSubstitutionTable.create(),
        'PfPl',
        version: kOS2Version1,
      );

      expect(table.achVendID, 'PfPl');
      expect(table.version, kOS2Version1);
    });

    test('reads the char range from the cmap format-4 subtable', () {
      final hmtx = _hmtx();

      final table = buildOS2Table(
        hmtx,
        _head(),
        _hhea(hmtx),
        _cmap(),
        GlyphSubstitutionTable.create(),
        'PfPl',
      );

      expect(table.usFirstCharIndex, 0xE001);
      expect(table.usLastCharIndex, 0xE001);
    });

    test('carries the ascender/descender/lineGap through from hhea', () {
      final hmtx = _hmtx();
      final hhea = _hhea(hmtx);

      final table = buildOS2Table(
        hmtx,
        _head(),
        hhea,
        _cmap(),
        GlyphSubstitutionTable.create(),
        'PfPl',
      );

      expect(table.sTypoAscender, hhea.ascender);
      expect(table.sTypoDescender, hhea.descender);
      expect(table.sTypoLineGap, hhea.lineGap);
    });

    test('leaves version-1+ fields null below version 1', () {
      final hmtx = _hmtx();

      final table = buildOS2Table(
        hmtx,
        _head(),
        _hhea(hmtx),
        _cmap(),
        GlyphSubstitutionTable.create(),
        'PfPl',
        version: kOS2Version0,
      );

      expect(table.ulCodePageRange1, isNull);
      expect(table.sxHeight, isNull);
      expect(table.usLowerOpticalPointSize, isNull);
    });

    test('fills version-5 fields by default', () {
      final hmtx = _hmtx();

      final table = buildOS2Table(
        hmtx,
        _head(),
        _hhea(hmtx),
        _cmap(),
        GlyphSubstitutionTable.create(),
        'PfPl',
      );

      expect(table.version, kOS2Version5);
      expect(table.usLowerOpticalPointSize, 0);
      expect(table.usUpperOpticalPointSize, 0xFFFE);
    });
  });
}
