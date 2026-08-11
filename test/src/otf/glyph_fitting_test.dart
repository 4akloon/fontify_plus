import 'dart:math';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/common/outline.dart';
import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:fontify_plus/src/otf/glyph_fitting.dart';
import 'package:test/test.dart';

const _curved =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M2 12C2 6 6 2 12 2C18 2 22 6 22 12" stroke="#000" '
    'stroke-width="1.5" stroke-linecap="round"/></svg>';

const _fitting = NormalizedFitting(ascender: 800, descender: -200);

GenericGlyph _squareGlyph({required num side, Rectangle<num>? bounds}) =>
    GenericGlyph(
      [
        Outline(
          pointList: [const Point(0, 0), Point(side, 0), Point(side, side)],
          isOnCurveList: [true, true, true],
          hasCompactCurves: false,
          hasQuadCurves: false,
          fillRule: FillRule.nonzero,
        ),
      ],
      bounds ?? Rectangle(0, 0, side, side),
    );

/// Asserts that [fitting]'s placement, applied to [glyph], reproduces
/// [GlyphFitting.fit] exactly — points and bounds both — not just points.
///
/// A placement that skipped bounds entirely, or rebuilt them incorrectly,
/// would still pass a points-only check: `resize`/`center`'s point-mapping
/// and their bounds-mapping are separate pieces of code, and only one of them
/// being wrong is enough to corrupt the glyph without moving a single point.
void _expectPlacementReproducesFit(GlyphFitting fitting, GenericGlyph glyph) {
  final fitted = fitting.fit(glyph);
  final placed = fitting.placementFor(glyph).apply(glyph);

  expect(placed.pointList.length, fitted.pointList.length);

  for (var i = 0; i < fitted.pointList.length; i++) {
    expect(placed.pointList[i].x, closeTo(fitted.pointList[i].x, 1e-9));
    expect(placed.pointList[i].y, closeTo(fitted.pointList[i].y, 1e-9));
  }

  expect(placed.bounds.left, closeTo(fitted.bounds.left, 1e-9));
  expect(placed.bounds.top, closeTo(fitted.bounds.top, 1e-9));
  expect(placed.bounds.width, closeTo(fitted.bounds.width, 1e-9));
  expect(placed.bounds.height, closeTo(fitted.bounds.height, 1e-9));
}

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
      final glyph = _squareGlyph(
        side: 10,
        bounds: const Rectangle(0, 0, 20, 20),
      );

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

      final fitted = fitting.fit(glyph);

      // Scaled by 100/20 = 5, so xMin moves from 5 to 25 — resize scales in
      // place, and ArtboardFitting never calls center to shift it back.
      expect(fitted.metrics.xMin, closeTo(25, 1e-9));
    });
  });

  group('GlyphPlacement', () {
    test('reproduces fit() when derived from the same glyph', () {
      final glyph = GenericGlyph.fromSvg('icon', _curved);

      final fitted = _fitting.fit(glyph);
      final placed = _fitting.placementFor(glyph).apply(glyph);

      expect(placed.pointList.length, fitted.pointList.length);

      for (var i = 0; i < fitted.pointList.length; i++) {
        expect(placed.pointList[i].x, closeTo(fitted.pointList[i].x, 1e-9));
        expect(placed.pointList[i].y, closeTo(fitted.pointList[i].y, 1e-9));
      }
    });

    test('one placement keeps two masters on the same centreline', () {
      final masters = glyphMastersFromSvg(
        'icon',
        _curved,
        StrokeWidthRange(1.33, 2),
      );

      final placement = _fitting.placementFor(masters.max);
      final thin = placement.apply(masters.min);
      final thick = placement.apply(masters.max);

      // Fitted independently, the thin master would be scaled up to fill the
      // same band and its centreline would move. Sharing the transform, its
      // ink stays strictly inside the thick master's.
      expect(thin.metrics.width, lessThan(thick.metrics.width));
      expect(thin.metrics.xMin, greaterThan(thick.metrics.xMin));
    });

    test('reproduces fit() bounds, not just points, for NormalizedFitting', () {
      _expectPlacementReproducesFit(
        _fitting,
        GenericGlyph.fromSvg('icon', _curved),
      );
    });

    test('reproduces fit() points and bounds for ArtboardFitting', () {
      const fitting = ArtboardFitting(fontHeight: 1000);
      // fit() never calls center() for this strategy, so a placement that
      // always translates — even by zero — would still corrupt bounds:
      // _translate's formula rebuilds the rectangle from bounds.bottom where
      // Rectangle's constructor expects top.
      final glyph = _squareGlyph(
        side: 10,
        bounds: const Rectangle(0, 0, 20, 20),
      );

      _expectPlacementReproducesFit(fitting, glyph);
    });
  });
}
