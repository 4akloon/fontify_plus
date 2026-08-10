import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:fontify_plus/src/svg/geometry/cubic_offset.dart';
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
  });
}
