import 'dart:math' as math;

import 'package:fontify_plus/src/common/outline.dart';
import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:fontify_plus/src/svg/outline_builder.dart';
import 'package:test/test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;
import 'package:vector_math/vector_math.dart';

List<Outline> fromPath(
  String pathData, {
  double height = 10,
  FillRule fillRule = FillRule.nonzero,
}) => outlinesFromCommands(
  vg.parseSvgPathData(pathData).commands,
  height: height,
  fillRule: fillRule,
);

Cubic line(double x0, double y0, double x1, double y1) =>
    Cubic.line(Vector2(x0, y0), Vector2(x1, y1));

/// A closed triangle of straight segments.
List<Cubic> get triangle => [
  line(0, 0, 1, 0),
  line(1, 0, 1, 1),
  line(1, 1, 0, 0),
];

void main() {
  group('outlinesFromCommands', () {
    test('flips y against the viewport height', () {
      // (0,0) is the top-left in SVG space and the bottom-left of a 10-tall
      // viewport once flipped.
      final outline = fromPath('M0 0 L1 0 L1 1 L0 1 Z').single;

      expect(outline.pointList.first, const math.Point<num>(0, 10));
    });

    test('marks every point on-curve for straight segments', () {
      final outline = fromPath('M0 0 L1 0 L1 1 L0 1 Z').single;

      expect(outline.isOnCurveList, everyElement(isTrue));
    });

    test("marks a cubic's two control points off-curve", () {
      final outline = fromPath('M0 0 C1 1 2 2 3 0').single;

      expect(outline.isOnCurveList, [true, false, false, true]);
    });

    test('carries an evenodd fill rule through', () {
      final outline = fromPath(
        'M0 0 L1 0 L1 1 Z',
        fillRule: FillRule.evenodd,
      ).single;

      expect(outline.fillRule, FillRule.evenodd);
    });

    test('carries a nonzero fill rule through', () {
      expect(fromPath('M0 0 L1 0 L1 1 Z').single.fillRule, FillRule.nonzero);
    });

    test('starts a fresh contour at every moveTo', () {
      // Two separate open strokes, no Z between them. Accumulating them into
      // one contour is what used to render an icon as a single zigzag.
      expect(fromPath('M0 0 L1 0 M5 5 L6 5'), hasLength(2));
    });

    test('flushes the last contour with no trailing Z', () {
      final outlines = fromPath('M0 0 L1 0 L1 1');

      expect(outlines, hasLength(1));
      expect(outlines.single.pointList, hasLength(3));
    });

    test('does not append the start point when closing', () {
      // The closing segment is implicit. Writing it costs a point in every
      // glyph and every path-derived assertion downstream assumes it is absent.
      final outline = fromPath('M0 0 L1 0 L1 1 Z').single;

      expect(outline.pointList, hasLength(3));
    });

    test('returns nothing for empty path data', () {
      expect(fromPath(''), isEmpty);
    });

    test('produces neither compact nor already-quadratic outlines', () {
      final outline = fromPath('M0 0 C1 1 2 2 3 0').single;

      expect(outline.hasCompactCurves, isFalse);
      expect(outline.hasQuadCurves, isFalse);
    });
  });

  group('outlinesFromContours', () {
    List<Outline> fromContours(List<List<Cubic>> contours) =>
        outlinesFromContours(contours, height: 10);

    test('is always nonzero', () {
      // The outliner leans on the nonzero rule to merge overlapping walls
      // rather than clipping them, so a stroke-derived contour must never
      // inherit evenodd from the path it came from.
      expect(fromContours([triangle]).single.fillRule, FillRule.nonzero);
    });

    test('flips y against the viewport height', () {
      expect(
        fromContours([triangle]).single.pointList.first,
        const math.Point<num>(0, 10),
      );
    });

    test('collapses a straight cubic to a single on-curve point', () {
      // Joins and caps emit many straight pieces. Spending three points on
      // each triples the point count of every stroked glyph.
      final outline = fromContours([triangle]).single;

      expect(outline.pointList, hasLength(3));
      expect(outline.isOnCurveList, everyElement(isTrue));
    });

    test('keeps the control points of a genuine curve', () {
      final curved = Cubic(
        Vector2(0, 0),
        Vector2(0, 5),
        Vector2(10, 5),
        Vector2(10, 0),
      );
      final outline = fromContours([
        [curved, line(10, 0, 0, 0)],
      ]).single;

      // Start, then the curve's two controls and its end. The closing
      // straight segment lands back on the start, and that repeat is dropped:
      // a contour's closing segment is implicit.
      expect(outline.isOnCurveList, [true, false, false, true]);
    });

    test(
      'keeps the final point of a contour that does not close on itself',
      () {
        // dropRepeatedStart must remove only a genuine repeat. An open chain
        // ends somewhere else, and losing that point would shorten the outline.
        final outline = fromContours([
          [line(0, 0, 1, 0), line(1, 0, 1, 1)],
        ]).single;

        expect(outline.pointList, hasLength(3));
        expect(outline.pointList.last, const math.Point<num>(1, 9));
      },
    );

    test('emits one outline per contour', () {
      expect(fromContours([triangle, triangle]), hasLength(2));
    });

    test('drops empty contours', () {
      expect(fromContours([<Cubic>[], <Cubic>[]]), isEmpty);
    });

    test('returns nothing for no contours', () {
      expect(fromContours([]), isEmpty);
    });
  });
}
