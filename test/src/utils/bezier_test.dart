import 'dart:math' as math;

import 'package:fontify_plus/src/utils/bezier.dart';
import 'package:test/test.dart';

/// Point on the cubic through [p0]..[p3] at parameter [t], for comparing
/// against a quadratic approximation.
math.Point<double> cubicAt(
  math.Point<num> p0,
  math.Point<num> p1,
  math.Point<num> p2,
  math.Point<num> p3,
  double t,
) {
  final u = 1 - t;

  final x =
      u * u * u * p0.x +
      3 * u * u * t * p1.x +
      3 * u * t * t * p2.x +
      t * t * t * p3.x;
  final y =
      u * u * u * p0.y +
      3 * u * u * t * p1.y +
      3 * u * t * t * p2.y +
      t * t * t * p3.y;

  return math.Point(x.toDouble(), y.toDouble());
}

math.Point<double> quadAt(
  math.Point<num> p0,
  math.Point<num> control,
  math.Point<num> end,
  double t,
) {
  final u = 1 - t;

  final x = u * u * p0.x + 2 * u * t * control.x + t * t * end.x;
  final y = u * u * p0.y + 2 * u * t * control.y + t * t * end.y;

  return math.Point(x.toDouble(), y.toDouble());
}

/// Worst distance between the quadratic chain and the source cubic.
///
/// The reference curve is sampled far more densely than the chain: with only
/// as many reference points as chain-side samples, the reference itself
/// becomes a coarse polyline near any fast-moving part of the curve, and the
/// resulting nearest-point search reports the polyline's own faceting error
/// rather than the chain's actual deviation from the smooth cubic.
double worstDeviation(
  math.Point<num> p0,
  math.Point<num> p1,
  math.Point<num> p2,
  math.Point<num> p3,
  List<QuadraticSegment> chain, {
  int samples = 40,
  int referenceSamples = 2000,
}) {
  var worst = 0.0;
  var start = p0;

  for (final segment in chain) {
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final onChain = quadAt(start, segment.control, segment.end, t);

      var nearest = double.infinity;

      for (var j = 0; j <= referenceSamples; j++) {
        final onCubic = cubicAt(p0, p1, p2, p3, j / referenceSamples);
        final d = onChain.distanceTo(onCubic);

        if (d < nearest) {
          nearest = d;
        }
      }

      if (nearest > worst) {
        worst = nearest;
      }
    }

    start = segment.end;
  }

  return worst;
}

void main() {
  group('quadCurveToCubic', () {
    test('produces control points that reconstruct the quadratic exactly', () {
      const qp0 = math.Point<num>(0, 0);
      const qp1 = math.Point<num>(5, 10);
      const qp2 = math.Point<num>(10, 0);

      final cubicControls = quadCurveToCubic(qp0, qp1, qp2);

      expect(cubicControls, hasLength(2));

      for (var i = 0; i <= 10; i++) {
        final t = i / 10;
        final onQuad = quadAt(qp0, qp1, qp2, t);
        final onCubic = cubicAt(
          qp0,
          cubicControls[0],
          cubicControls[1],
          qp2,
          t,
        );

        expect(onQuad.x, closeTo(onCubic.x, 1e-9));
        expect(onQuad.y, closeTo(onCubic.y, 1e-9));
      }
    });
  });

  group('cubicCurveToQuadratics', () {
    test('returns a chain that starts and ends where the cubic does', () {
      const p0 = math.Point<num>(0, 0);
      const p1 = math.Point<num>(0, 10);
      const p2 = math.Point<num>(10, 10);
      const p3 = math.Point<num>(10, 0);

      final chain = cubicCurveToQuadratics(p0, p1, p2, p3);

      expect(chain.first.control, isNotNull);
      expect(chain.last.end, p3);
    });

    test('stays within tolerance of a curved cubic', () {
      const p0 = math.Point<num>(0, 0);
      const p1 = math.Point<num>(0, 20);
      const p2 = math.Point<num>(20, 20);
      const p3 = math.Point<num>(20, 0);

      const tolerance = kQuadraticApproximationTolerance;
      final chain = cubicCurveToQuadratics(p0, p1, p2, p3, tolerance);

      expect(
        worstDeviation(p0, p1, p2, p3, chain),
        lessThanOrEqualTo(tolerance),
      );
    });

    test('a tighter tolerance never produces fewer segments', () {
      const p0 = math.Point<num>(0, 0);
      const p1 = math.Point<num>(0, 30);
      const p2 = math.Point<num>(30, 30);
      const p3 = math.Point<num>(30, 0);

      final loose = cubicCurveToQuadratics(p0, p1, p2, p3, 2);
      final tight = cubicCurveToQuadratics(p0, p1, p2, p3, 0.1);

      expect(tight.length, greaterThanOrEqualTo(loose.length));
    });

    test('a straight cubic needs only one segment', () {
      const p0 = math.Point<num>(0, 0);
      const p1 = math.Point<num>(5, 0);
      const p2 = math.Point<num>(10, 0);
      const p3 = math.Point<num>(15, 0);

      final chain = cubicCurveToQuadratics(p0, p1, p2, p3);

      expect(chain, hasLength(1));
    });

    test('a degenerate cubic (all points equal) needs only one segment', () {
      const p = math.Point<num>(3, 3);
      final chain = cubicCurveToQuadratics(p, p, p, p);

      expect(chain, hasLength(1));
      expect(chain.single.end, p);
    });

    test('chain segments connect end to end', () {
      const p0 = math.Point<num>(0, 0);
      const p1 = math.Point<num>(-40, 40);
      const p2 = math.Point<num>(40, 40);
      const p3 = math.Point<num>(0, 0);

      final chain = cubicCurveToQuadratics(p0, p1, p2, p3, 0.1);

      var start = p0;
      for (final segment in chain) {
        // Each segment's implicit start is the previous segment's end.
        start = segment.end;
      }

      expect(start, p3);
    });
  });
}
