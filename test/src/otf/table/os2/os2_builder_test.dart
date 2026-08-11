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
  GenericGlyphMetrics(xMin: 0, xMax: 700, yMin: 0, yMax: 800), // one icon glyph
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

      expect(table.version0.achVendID, 'PfPl');
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

      expect(table.version0.usFirstCharIndex, 0xE001);
      expect(table.version0.usLastCharIndex, 0xE001);
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

      expect(table.version0.sTypoAscender, hhea.ascender);
      expect(table.version0.sTypoDescender, hhea.descender);
      expect(table.version0.sTypoLineGap, hhea.lineGap);
    });

    test('leaves the version-1+ groups null below version 1', () {
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

      expect(table.version1, isNull);
      expect(table.version4, isNull);
      expect(table.version5, isNull);
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
      expect(table.version5?.usLowerOpticalPointSize, 0);
      expect(table.version5?.usUpperOpticalPointSize, 0xFFFE);
    });

    test('pins usWeightClass to 400 (Regular)', () {
      // buildOS2Table takes no axis or range argument, so this only pins
      // the constant itself, not any claim about behaving consistently
      // across a wght range — it can't vary here regardless. An honest
      // usWeightClass for the 1.33-2.0 stroke-width axis this package's
      // variable font carries would be 2 ("Extra-thin"), but generic
      // tooling that reads this field without instancing the font would
      // then treat the icon font as thinner than Thin. 400 is the
      // deliberate, documented choice — see the comment in
      // os2_builder.dart. A test that actually varies the axis and checks
      // usWeightClass stays 400 belongs in Task 19, once a real variable
      // font exists to build it from.
      final hmtx = _hmtx();

      final table = buildOS2Table(
        hmtx,
        _head(),
        _hhea(hmtx),
        _cmap(),
        GlyphSubstitutionTable.create(),
        'PfPl',
      );

      expect(table.version0.usWeightClass, 400);
    });
  });
}
