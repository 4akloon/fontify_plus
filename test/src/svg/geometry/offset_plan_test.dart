import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:fontify_plus/src/svg/geometry/cubic_offset.dart';
import 'package:fontify_plus/src/svg/geometry/offset_approximation.dart';
import 'package:fontify_plus/src/svg/geometry/tolerances.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// A quarter-circle-ish cubic, curved enough that offsetting subdivides it.
final _curve = Cubic(
  Vector2(0, 0),
  Vector2(0, 6),
  Vector2(6, 10),
  Vector2(12, 10),
);

CubicOffsetter _offsetter(double distance) =>
    CubicOffsetter(distance: distance, tolerance: kCurveTolerance);

void main() {
  group('OffsetPlan', () {
    test('evaluating at the planning distance reproduces offset()', () {
      final offsetter = _offsetter(3);

      final direct = offsetter.offset(_curve);
      final planned = offsetter.plan(_curve).evaluate(3);

      expect(planned.length, direct.length);

      for (var i = 0; i < direct.length; i++) {
        expect(planned[i].p0.distanceTo(direct[i].p0), lessThan(1e-9));
        expect(planned[i].p3.distanceTo(direct[i].p3), lessThan(1e-9));
      }
    });

    test('keeps the piece count fixed across widths', () {
      // Planned wide, evaluated narrow: the narrow result must not re-derive
      // its own, shallower subdivision.
      final plan = _offsetter(3).plan(_curve);

      expect(plan.evaluate(0.5).length, plan.pieces.length);
      expect(plan.evaluate(3).length, plan.pieces.length);
    });

    test('a curved source really does subdivide', () {
      // Guards the test above from passing trivially on a single piece.
      expect(_offsetter(3).plan(_curve).pieces.length, greaterThan(1));
    });

    test('evaluation is affine in the distance', () {
      final plan = _offsetter(3).plan(_curve);

      final low = plan.evaluate(1);
      final high = plan.evaluate(3);
      final mid = plan.evaluate(2);

      for (var i = 0; i < mid.length; i++) {
        final expected = (low[i].p1 + high[i].p1) / 2;

        // Unlike the other assertions here, low/mid/high are three genuinely
        // separate evaluations rather than shared sub-expressions, so
        // Vector2's float32 storage rounds each independently. For this
        // fixture that residual is deterministic and measured at
        // ~1.9e-6; 1e-5 clears it with headroom while still catching a
        // real break in affine-ness — e.g. a piece flipping between its
        // curve and chord branch across distances — which would be orders
        // of magnitude larger. This bound is specific to this fixture, not
        // a general float32 noise floor: other curve/distance combinations
        // have been observed to residual as high as ~6e-4.
        expect(mid[i].p1.distanceTo(expected), lessThan(1e-5));
      }
    });

    test(
      'built at the range maximum, evaluation tracks the true offset '
      'across the whole range — built at the minimum, it does not',
      () {
        // Piece count is fixed by the distance a plan is built at, so every
        // structural check above — count, affine interpolation — passes
        // identically whichever end of a range a plan is built at. Only
        // geometric fidelity tells the two apart, and only over a range wide
        // enough to separate them: at this package's shipped stroke-width
        // range (1.33-2.0, i.e. distance 0.665-1.0) building at either end
        // gives the same worst-case deviation on this fixture, ~6.6e-3.
        // Phase 4 is what makes a wider range configurable, so the discipline
        // has to be pinned — and tested — before it does.
        const minDistance = 0.25;
        const maxDistance = 3.0;

        // Worst deviation from the true offset, replaying a plan built at
        // [planDistance] across every distance in [minDistance, maxDistance].
        double worstDeviationOver(double planDistance) {
          final plan = _offsetter(planDistance).plan(_curve);
          var worst = 0.0;

          const samples = 200;
          for (var i = 0; i <= samples; i++) {
            final distance =
                minDistance + (maxDistance - minDistance) * i / samples;
            final pieces = plan.evaluate(distance);

            for (var j = 0; j < pieces.length; j++) {
              final deviation = maxOffsetDeviation(
                plan.pieces[j].curve,
                pieces[j],
                distance,
              );

              if (deviation > worst) {
                worst = deviation;
              }
            }
          }

          return worst;
        }

        // Built at the maximum: every shallower distance in range replays
        // the same subdivision at less demanding curvature, so it stays
        // close to the true offset throughout.
        expect(
          worstDeviationOver(maxDistance),
          lessThanOrEqualTo(kCurveTolerance),
        );

        // Built at the minimum: the same subdivision, sized for the
        // shallowest offset in range, is far too coarse once evaluated at
        // the far end — measured at ~4.8x over tolerance here, not a
        // rounding-sized miss.
        expect(
          worstDeviationOver(minDistance),
          greaterThan(kCurveTolerance * 4),
        );
      },
    );
  });
}
