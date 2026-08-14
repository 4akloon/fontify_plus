import 'dart:io';

import 'package:fontify_plus/fontify_plus.dart';
import 'package:fontify_plus/src/otf/defaults.dart';
import 'package:test/test.dart';

import '../constant.dart';

const _kTestCompSvgPathList = [
  '$kTestAssetsDir/svg/comp_first.svg',
  '$kTestAssetsDir/svg/comp_second.svg',
  '$kTestAssetsDir/svg/comp_third.svg',
];

/// An icon drawn to fill its artboard.
const _fullBleed = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
<path d="M0 0 H16 V16 H0 Z" fill="#000" />
</svg>
''';

/// The same artboard, with an icon drawn at a quarter of the size.
const _quarter = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
<path d="M6 6 H10 V10 H6 Z" fill="#000" />
</svg>
''';

void main() {
  group('Normalization', () {
    List<GenericGlyph> createGlyphList() => [
      for (final path in _kTestCompSvgPathList)
        GenericGlyph.fromSvg(path, File(path).readAsStringSync()),
    ];

    /// Longest side of each non-default glyph, in font units.
    List<num> longestSides(List<GenericGlyph> glyphList) => [
      for (final g in glyphList)
        if (g.metrics.height > g.metrics.width)
          g.metrics.height
        else
          g.metrics.width,
    ];

    test('Metrics, normalization is off', () {
      final font = OpenTypeFont.createFromGlyphs(
        glyphList: createGlyphList(),
        normalize: false,
      );
      final widthList = font.hmtx.hMetrics.map((e) => e.advanceWidth);
      const unitsPerEm = kDefaultOpenTypeUnitsPerEm;

      expect(widthList, [350, 333, unitsPerEm, unitsPerEm, unitsPerEm]);

      // The artboard maps straight onto the em square, so there is no band to
      // hang below the baseline.
      expect(font.hhea.ascender, unitsPerEm);
      expect(font.hhea.descender, 0);
    });

    test('Metrics, normalization is on', () {
      final font = OpenTypeFont.createFromGlyphs(
        glyphList: createGlyphList(),
        normalize: true,
      );

      expect(font.hhea.ascender, 850);
      expect(font.hhea.descender, -150);
    });

    test('normalization fits a glyph to the full em square', () {
      // Regression guard: the scale factor was computed as ascender + descender
      // rather than the difference. With the defaults that is 700 rather than
      // 1000, so every glyph came out at 70% of the size it asked for.
      const ascender = 850;
      const descender = -150;
      const emSpan = ascender - descender;

      final glyph = GenericGlyph.fromSvg('quarter', _quarter);
      final resized = glyph.resize(ascender: ascender, descender: descender);

      final longest = longestSides([resized]).single;

      expect(
        longest,
        closeTo(emSpan, emSpan * 0.02),
        reason: 'a normalized glyph must fill the descender-to-ascender span',
      );
    });

    test('normalization makes differently sized icons the same size', () {
      // This is what normalization is for by default: icons whose artboards
      // disagree still share a visual size.
      final glyphs = [
        GenericGlyph.fromSvg('full', _fullBleed),
        GenericGlyph.fromSvg('quarter', _quarter),
      ].map((g) => g.resize(ascender: 850, descender: -150)).toList();

      final sides = longestSides(glyphs);

      expect(sides.first, closeTo(sides.last, 1));
    });

    test('without normalization an icon keeps the size it was drawn at', () {
      // The quarter-size icon covers a quarter of the artboard, so it must
      // still cover a quarter of the em square. Normalization would inflate it
      // to match the full-bleed one and lose that distinction.
      const unitsPerEm = kDefaultOpenTypeUnitsPerEm;

      final glyphs = [
        GenericGlyph.fromSvg('full', _fullBleed),
        GenericGlyph.fromSvg('quarter', _quarter),
      ].map((g) => g.resize(fontHeight: unitsPerEm)).toList();

      final sides = longestSides(glyphs);

      expect(sides.first, closeTo(unitsPerEm, unitsPerEm * 0.02));
      expect(sides.last, closeTo(unitsPerEm / 4, unitsPerEm * 0.02));
    });

    test('svgToOtf normalizes by default', () {
      final result = svgToOtf(
        svgMap: {'full': _fullBleed, 'quarter': _quarter},
      );

      expect(result.font.hhea.descender, -kDefaultBaselineExtension);
    });

    test('svgToOtf can keep artboard sizes with normalize: false', () {
      final result = svgToOtf(
        svgMap: {'full': _fullBleed, 'quarter': _quarter},
        normalize: false,
      );

      expect(result.font.hhea.descender, 0);
    });
  });
}
