import 'dart:math';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/common/outline.dart';
import 'package:fontify_plus/src/otf/glyph_fitting.dart';
import 'package:test/test.dart';

GenericGlyph _squareGlyph({required num side, Rectangle<num>? bounds}) =>
    GenericGlyph(
      [
        Outline(
          [const Point(0, 0), Point(side, 0), Point(side, side)],
          [true, true, true],
          false,
          false,
          FillRule.nonzero,
        ),
      ],
      bounds ?? Rectangle(0, 0, side, side),
    );

void main() {
  group('NormalizedFitting.fit', () {
    test('resizes the ink to the ascender/descender band, then centers it', () {
      const fitting = NormalizedFitting(ascender: 1000, descender: 0);
      final glyph = _squareGlyph(side: 10);

      final fitted = fitting.fit(glyph);

      // resize(ascender: 1000, descender: 0) on a 10-unit square scales to
      // 1000; center then shifts the ink's xMin back to 0.
      expect(fitted.metrics.width, closeTo(1000, 1e-9));
      expect(fitted.metrics.xMin, closeTo(0, 1e-9));
    });
  });

  group('ArtboardFitting.fit', () {
    test('resizes against the artboard (bounds), without centering', () {
      const fitting = ArtboardFitting(fontHeight: 1000);
      // A 10-unit square ink inside a 20-unit artboard.
      final glyph =
          _squareGlyph(side: 10, bounds: const Rectangle(0, 0, 20, 20));

      final fitted = fitting.fit(glyph);

      // fontHeight maps the 20-unit artboard onto 1000, so the 10-unit ink
      // scales to 500 — half the requested font height, not all of it.
      expect(fitted.metrics.width, closeTo(500, 1e-9));
    });

    test('does not shift the ink to start at x=0 (no centering step)', () {
      const fitting = ArtboardFitting(fontHeight: 100);
      final glyph = GenericGlyph(
        [
          Outline(
            [const Point(5, 5), const Point(15, 5), const Point(15, 15)],
            [true, true, true],
            false,
            false,
            FillRule.nonzero,
          ),
        ],
        const Rectangle(0, 0, 20, 20),
      );

      final fitted = fitting.fit(glyph);

      // Scaled by 100/20 = 5, so xMin moves from 5 to 25 — resize scales in
      // place, and ArtboardFitting never calls center to shift it back.
      expect(fitted.metrics.xMin, closeTo(25, 1e-9));
    });
  });
}
