import 'dart:math' as math;

import 'package:fontify_plus/src/svg/stroke/stroke_outliner.dart';
import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';
import 'package:test/test.dart';

import 'contour_reader.dart';

/// Outlines [pathData] as a one-liner, which is all these tests need of
/// [StrokeOutliner].
String? outlineStrokeToPathData(String pathData, StrokeProperties stroke) =>
    StrokeOutliner(stroke).outline(pathData);

void main() {
  group('outlineStrokeToPathData', () {
    test('gives a straight stroke the area of its bounding rectangle', () {
      // A 10-long, 2-wide butt-capped stroke covers exactly 20 square units.
      final outlined = outlineStrokeToPathData('M0 0H10', kStroke);

      expect(outlined, isNotNull);
      expect(totalArea(outlined!), closeTo(20, 0.01));
    });

    test('extends a square cap by half the stroke width at each end', () {
      final outlined = outlineStrokeToPathData(
        'M0 0H10',
        const StrokeProperties(width: 2, cap: LineCap.square),
      );

      // 10 + 1 + 1 long, 2 wide.
      expect(totalArea(outlined!), closeTo(24, 0.01));
    });

    test('adds a half disc at each end for a round cap', () {
      final outlined = outlineStrokeToPathData(
        'M0 0H10',
        const StrokeProperties(width: 2, cap: LineCap.round),
      );

      // 20 for the body, plus a unit circle spread across the two caps.
      //
      // The arc is flattened into an inscribed polygon, so it approaches the
      // true circle from below and never exceeds it. Bounding it on both sides
      // pins the geometry without asserting a segment count the flattening
      // tolerance is free to change.
      const body = 20.0;
      const disc = math.pi;

      expect(totalArea(outlined!), lessThanOrEqualTo(body + disc));
      expect(totalArea(outlined), greaterThan(body + disc * 0.95));
    });

    test('produces a hollow ring for a closed stroke', () {
      // A stroked 10x10 square: two contours, wound opposite so the nonzero
      // rule leaves the interior empty.
      final outlined = outlineStrokeToPathData(
        'M0 0H10V10H0Z',
        const StrokeProperties(width: 2, join: LineJoin.miter),
      );

      final parsed = contours(outlined!);
      expect(parsed, hasLength(2));

      final areas = parsed.map(signedArea).toList();
      expect(
        areas[0].sign,
        isNot(areas[1].sign),
        reason: 'inner and outer walls must wind opposite to leave a hole',
      );

      // Outer 12x12 minus inner 8x8.
      final ring = areas.map((a) => a.abs()).reduce((a, b) => a - b).abs();
      expect(ring, closeTo(144 - 64, 0.01));
    });

    test('keeps crossing subpaths as separate contours', () {
      // A plus sign: two strokes that cross. They must not be spliced into one
      // contour, and the nonzero rule merges them where they overlap.
      final outlined = outlineStrokeToPathData('M5 0V10M0 5H10', kStroke);

      expect(contours(outlined!), hasLength(2));
    });

    test('returns null when there is nothing to stroke', () {
      expect(outlineStrokeToPathData('', kStroke), isNull);
    });

    test('falls back to a bevel past the miter limit', () {
      // A very sharp corner would spike far past the join; stroke-miterlimit
      // caps it. The tight limit must produce strictly less area than a
      // generous one.
      const path = 'M0 0L10 0L0 0.5';

      final clipped = outlineStrokeToPathData(
        path,
        const StrokeProperties(width: 2, miterLimit: 1),
      );
      final spiked = outlineStrokeToPathData(
        path,
        const StrokeProperties(width: 2, miterLimit: 100),
      );

      expect(totalArea(clipped!), lessThan(totalArea(spiked!)));
    });

    test('emits curves rather than a dense polyline', () {
      // Offsetting only works on line segments, so the outline is built as a
      // flattened polyline and then refitted. Shipping the polyline verbatim
      // would cost dozens of commands per icon for no extra accuracy.
      final outlined = outlineStrokeToPathData('M0 0C0 5 10 5 10 0', kStroke)!;

      expect(outlined, contains('C'));
      // The flattened polyline behind this outline runs to several hundred
      // points; refitting has to bring it back to the order of the curve.
      expect(
        commandCount(outlined),
        lessThan(30),
        reason: 'a refitted curve should need far fewer commands than samples',
      );
    });

    test('stays accurate after refitting', () {
      // Compactness is only worth having if the shape survives it. A stroke of
      // width 2 along a curve of arc length L covers about 2L.
      final outlined = outlineStrokeToPathData('M0 0C0 5 10 5 10 0', kStroke)!;

      final contour = contours(outlined).single;
      final xs = contour.map((p) => p[0]);
      final ys = contour.map((p) => p[1]);

      // Both ends of this curve leave vertically, so the stroke spreads
      // sideways there and the butt caps sit flat on y = 0.
      expect(xs.reduce(math.min), closeTo(-1, 0.05));
      expect(xs.reduce(math.max), closeTo(11, 0.05));
      expect(ys.reduce(math.min), closeTo(0, 0.05));

      // The curve peaks at 3.75, plus half a stroke width.
      expect(ys.reduce(math.max), closeTo(4.75, 0.05));
    });

    test('keeps a miter corner sharp through refitting', () {
      // Curve fitting is smooth by construction, so a corner survives only if
      // the outliner marks it and the run is cut there. If that breaks, the
      // sharp tip is quietly rounded away.
      final outlined = outlineStrokeToPathData(
        'M0 0L10 0L10 10',
        const StrokeProperties(width: 2, miterLimit: 10),
      )!;

      final contour = contours(outlined).single;

      // The outer miter tip of a right angle sits at (11, -1).
      final reachesTip = contour.any(
        (p) => (p[0] - 11).abs() < 0.01 && (p[1] + 1).abs() < 0.01,
      );

      expect(reachesTip, isTrue, reason: 'the miter tip was rounded off');
    });

    test('keeps a square cap sharp through refitting', () {
      final outlined = outlineStrokeToPathData(
        'M0 0H10',
        const StrokeProperties(width: 2, cap: LineCap.square),
      )!;

      // Square caps are four right angles; rounding any of them loses area.
      expect(totalArea(outlined), closeTo(24, 0.01));
    });
  });
}
