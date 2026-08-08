import 'dart:math';

import 'package:fontify_plus/src/common/outline.dart';
import 'package:test/test.dart';

Outline outlineOf(
  List<Point<num>> points,
  List<bool> onCurve, {
  bool compact = false,
  bool quad = false,
  FillRule fillRule = FillRule.nonzero,
}) => Outline(points, onCurve, compact, quad, fillRule);

void main() {
  group('Outline.copy', () {
    test('produces independent point and on-curve lists', () {
      final original = outlineOf([const Point(0, 0)], [true]);
      final copy = original.copy();

      copy.pointList.add(const Point(1, 1));
      copy.isOnCurveList.add(true);

      expect(original.pointList, hasLength(1));
      expect(original.isOnCurveList, hasLength(1));
    });

    test('preserves the flags and fill rule', () {
      final original = outlineOf(
        [const Point(0, 0)],
        [true],
        compact: true,
        quad: true,
        fillRule: FillRule.evenodd,
      );
      final copy = original.copy();

      expect(copy.hasCompactCurves, isTrue);
      expect(copy.hasQuadCurves, isTrue);
      expect(copy.fillRule, FillRule.evenodd);
    });
  });

  group('Outline.decompactImplicitPoints', () {
    test('does nothing when the outline is not compact', () {
      final outline = outlineOf([const Point(0, 0)], [true]);
      final before = [...outline.pointList];

      outline.decompactImplicitPoints();

      expect(outline.pointList, before);
    });

    test('throws for a compact outline with no quadratic curves', () {
      final outline = outlineOf(
        [const Point(0, 0)],
        [true],
        compact: true,
        quad: false,
      );

      expect(outline.decompactImplicitPoints, throwsUnsupportedError);
    });

    test('inserts the midpoint between two consecutive off-curve points', () {
      final outline = outlineOf(
        [
          const Point(0, 0),
          const Point(2, 4),
          const Point(6, 4),
          const Point(8, 0),
        ],
        [true, false, false, true],
        compact: true,
        quad: true,
      );

      outline.decompactImplicitPoints();

      expect(outline.pointList, [
        const Point(0, 0),
        const Point(2, 4),
        const Point(4, 4),
        const Point(6, 4),
        const Point(8, 0),
      ]);
      expect(outline.isOnCurveList, [true, false, true, false, true]);
      expect(outline.hasCompactCurves, isFalse);
    });

    test('duplicates the start point when the contour ends off-curve', () {
      final outline = outlineOf(
        [const Point(0, 0), const Point(2, 4)],
        [true, false],
        compact: true,
        quad: true,
      );

      outline.decompactImplicitPoints();

      expect(outline.pointList, [
        const Point(0, 0),
        const Point(2, 4),
        const Point(0, 0),
      ]);
      expect(outline.isOnCurveList, [true, false, true]);
    });
  });

  group('Outline.compactImplicitPoints', () {
    test('throws for a non-quadratic outline', () {
      final outline = outlineOf([const Point(0, 0)], [true]);

      expect(outline.compactImplicitPoints, throwsUnsupportedError);
    });

    test('does nothing when already compact', () {
      final outline = outlineOf(
        [const Point(0, 0), const Point(2, 4)],
        [true, false],
        compact: true,
        quad: true,
      );
      final before = [...outline.pointList];

      outline.compactImplicitPoints();

      expect(outline.pointList, before);
    });

    test('removes a midpoint left over from decompacting', () {
      // The exact inverse of the decompactImplicitPoints midpoint test.
      final outline = outlineOf(
        [
          const Point(0, 0),
          const Point(2, 4),
          const Point(4, 4),
          const Point(6, 4),
          const Point(8, 0),
        ],
        [true, false, true, false, true],
        quad: true,
      );

      outline.compactImplicitPoints();

      expect(outline.pointList, [
        const Point(0, 0),
        const Point(2, 4),
        const Point(6, 4),
        const Point(8, 0),
      ]);
      expect(outline.hasCompactCurves, isTrue);
    });

    test('keeps an on-curve point that is not the exact midpoint', () {
      // A genuine authored anchor between two curves, not an implicit point —
      // removing it would silently change the shape.
      final outline = outlineOf(
        [
          const Point(0, 0),
          const Point(2, 4),
          const Point(5, 5),
          const Point(6, 4),
          const Point(8, 0),
        ],
        [true, false, true, false, true],
        quad: true,
      );

      outline.compactImplicitPoints();

      expect(outline.pointList, hasLength(5));
    });

    test('removes a trailing duplicate of the start point', () {
      final outline = outlineOf(
        [const Point(0, 0), const Point(2, 4), const Point(0, 0)],
        [true, false, true],
        quad: true,
      );

      outline.compactImplicitPoints();

      expect(outline.pointList, [const Point(0, 0), const Point(2, 4)]);
    });

    test('does not remove anything from a single-point contour', () {
      final outline = outlineOf([const Point(0, 0)], [true], quad: true);

      expect(outline.compactImplicitPoints, returnsNormally);
      expect(outline.pointList, [const Point(0, 0)]);
    });
  });

  group('Outline.cubicToQuad', () {
    test('does nothing when the outline is already quadratic', () {
      final outline = outlineOf([const Point(0, 0)], [true], quad: true);
      final before = [...outline.pointList];

      outline.cubicToQuad();

      expect(outline.pointList, before);
    });

    test('throws for a compact outline', () {
      final outline = outlineOf(
        [const Point(0, 0), const Point(1, 1)],
        [true, false],
        compact: true,
      );

      expect(outline.cubicToQuad, throwsUnsupportedError);
    });

    test('carries a straight segment through unchanged', () {
      final outline = outlineOf(
        [const Point(0, 0), const Point(10, 0)],
        [true, true],
      );

      outline.cubicToQuad();

      expect(outline.pointList, [const Point(0, 0), const Point(10, 0)]);
      expect(outline.isOnCurveList, [true, true]);
      expect(outline.hasQuadCurves, isTrue);
    });

    test('closes the last cubic segment back to the contour start', () {
      // Three points — on, off, off — is the whole contour: the curve's own
      // end point is implicit, closing back to the start.
      final outline = outlineOf(
        [const Point(0, 0), const Point(0, 10), const Point(10, 10)],
        [true, false, false],
      );

      outline.cubicToQuad();

      expect(outline.pointList.first, const Point(0, 0));
      expect(outline.pointList.last, const Point(0, 0));
      expect(outline.isOnCurveList.first, isTrue);
      expect(outline.isOnCurveList.last, isTrue);
    });

    test('produces an alternating off/on pattern for each cubic segment', () {
      final outline = outlineOf(
        [
          const Point(0, 0),
          const Point(0, 20),
          const Point(20, 20),
          const Point(20, 0),
        ],
        [true, false, false, true],
      );

      outline.cubicToQuad();

      // Every point but the leading start is part of an [off, on] pair.
      expect((outline.pointList.length - 1) % 2, 0);
      for (var i = 1; i < outline.isOnCurveList.length; i += 2) {
        expect(outline.isOnCurveList[i], isFalse);
        expect(outline.isOnCurveList[i + 1], isTrue);
      }
    });

    test('rejects a cubic segment with only one control point', () {
      final outline = outlineOf(
        [const Point(0, 0), const Point(1, 1), const Point(2, 0)],
        [true, false, true],
      );

      expect(outline.cubicToQuad, throwsStateError);
    });
  });

  group('Outline.quadToCubic', () {
    test('does nothing when there are no quadratic curves', () {
      final outline = outlineOf([const Point(0, 0)], [true]);
      final before = [...outline.pointList];

      outline.quadToCubic();

      expect(outline.pointList, before);
    });

    test('throws for a compact outline', () {
      final outline = outlineOf(
        [const Point(0, 0), const Point(1, 1)],
        [true, false],
        compact: true,
        quad: true,
      );

      expect(outline.quadToCubic, throwsUnsupportedError);
    });

    test('replaces one control point with two, and clears hasQuadCurves', () {
      final outline = outlineOf(
        [const Point(0, 0), const Point(5, 10), const Point(10, 0)],
        [true, false, true],
        quad: true,
      );

      outline.quadToCubic();

      expect(outline.pointList, hasLength(4));
      expect(outline.isOnCurveList, [true, false, false, true]);
      expect(outline.hasQuadCurves, isFalse);
    });

    test('closes the last quadratic segment back to the contour start', () {
      // Already decompacted — the trailing on-curve point duplicates the
      // start, the way decompactImplicitPoints leaves it. quadToCubic relies
      // on that point being present rather than reconstructing it.
      final outline = outlineOf(
        [const Point(0, 0), const Point(5, 5), const Point(0, 0)],
        [true, false, true],
        quad: true,
      );

      outline.quadToCubic();

      expect(outline.pointList.last, const Point(0, 0));
    });

    test(
      'round-trips through cubicToQuad and back to the same on-curve points',
      () {
        final outline = outlineOf(
          [
            const Point(0, 0),
            const Point(0, 20),
            const Point(20, 20),
            const Point(20, 0),
          ],
          [true, false, false, true],
        );

        outline.cubicToQuad();
        outline.quadToCubic();

        final onCurvePoints = [
          for (var i = 0; i < outline.pointList.length; i++)
            if (outline.isOnCurveList[i]) outline.pointList[i],
        ];

        // This describes one open cubic segment from (0,0) to (20,0), not a
        // closed loop — there is no implicit closing point to recover here.
        expect(onCurvePoints.first, const Point(0, 0));
        expect(onCurvePoints.last, const Point(20, 0));
      },
    );
  });
}
