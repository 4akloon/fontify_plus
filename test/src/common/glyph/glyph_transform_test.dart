import 'dart:math';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/common/outline.dart';
import 'package:test/test.dart';

GenericGlyph squareGlyph({
  required num side,
  Rectangle<num>? bounds,
}) => GenericGlyph(
  [
    Outline(
      pointList: [
        const Point(0, 0),
        Point(side, 0),
        Point(side, side),
        const Point(0, 0),
      ],
      isOnCurveList: [true, true, true, true],
      hasCompactCurves: false,
      hasQuadCurves: false,
      fillRule: FillRule.nonzero,
    ),
  ],
  bounds ?? Rectangle(0, 0, side, side),
);

void main() {
  group('GlyphTransform.resize', () {
    test('throws when neither ascender/descender nor fontHeight is given', () {
      final glyph = squareGlyph(side: 10);

      expect(glyph.resize, throwsArgumentError);
    });

    test('is a no-op when the requested band matches the current size', () {
      final glyph = squareGlyph(side: 10);
      final resized = glyph.resize(ascender: 10, descender: 0);

      expect(resized, same(glyph));
    });

    test('scales by fontHeight against the artboard, not the ink', () {
      // bounds is the 20-unit artboard; the ink is only a 10-unit square
      // inside it. fontHeight maps the ARTBOARD onto the em, so the ink
      // scales by 1000/20, not 1000/10. metrics truncates to integer font
      // units, so the ratio is chosen to divide evenly.
      final glyph = squareGlyph(
        side: 10,
        bounds: const Rectangle(0, 0, 20, 20),
      );

      final resized = glyph.resize(fontHeight: 1000);

      expect(resized.metrics.width, 500);
    });

    test('scales by the ascender/descender band against the ink', () {
      // Normalization maps the ink's own longest side onto the band, unlike
      // fontHeight above.
      final glyph = squareGlyph(
        side: 10,
        bounds: const Rectangle(0, 0, 20, 20),
      );

      final resized = glyph.resize(ascender: 1000, descender: 0);

      expect(resized.metrics.width, closeTo(1000, 1e-9));
    });

    test('scales bounds by the same ratio as the points', () {
      final glyph = squareGlyph(side: 10);
      final resized = glyph.resize(fontHeight: 100);

      expect(resized.bounds.width, closeTo(100, 1e-9));
    });

    test('preserves metadata', () {
      final glyph = GenericGlyph(
        squareGlyph(side: 10).outlines,
        const Rectangle(0, 0, 10, 10),
        GenericGlyphMetadata(name: 'square'),
      );

      expect(glyph.resize(fontHeight: 100).metadata.name, 'square');
    });
  });

  group('GlyphTransform.center', () {
    test('shifts the ink so its bounding box starts at x=0', () {
      final glyph = GenericGlyph(
        [
          Outline(
            pointList: [
              const Point(5, 5),
              const Point(15, 5),
              const Point(15, 15),
            ],
            isOnCurveList: [true, true, true],
            hasCompactCurves: false,
            hasQuadCurves: false,
            fillRule: FillRule.nonzero,
          ),
        ],
        const Rectangle(0, 0, 20, 20),
      );

      final centered = glyph.center(1000, 0);

      expect(centered.metrics.xMin, 0);
    });

    test('centres the ink within the ascender/descender band vertically', () {
      // A 10-tall glyph centred in a 0..1000 band should sit with equal space
      // above and below: yMin = (1000-10)/2.
      final glyph = GenericGlyph(
        [
          Outline(
            pointList: [
              const Point(0, 0),
              const Point(10, 0),
              const Point(10, 10),
            ],
            isOnCurveList: [true, true, true],
            hasCompactCurves: false,
            hasQuadCurves: false,
            fillRule: FillRule.nonzero,
          ),
        ],
        const Rectangle(0, 0, 10, 10),
      );

      final centered = glyph.center(1000, 0);

      expect(centered.metrics.yMin, closeTo(495, 1e-9));
      expect(centered.metrics.yMax, closeTo(505, 1e-9));
    });

    test('does not mutate the original glyph', () {
      final glyph = squareGlyph(side: 10);
      final before = glyph.outlines.single.pointList.first;

      glyph.center(1000, 0);

      expect(glyph.outlines.single.pointList.first, before);
    });
  });
}
