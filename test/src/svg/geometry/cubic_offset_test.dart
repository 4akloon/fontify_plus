import 'package:fontify_plus/src/svg/geometry/cubic.dart';
import 'package:fontify_plus/src/svg/geometry/cubic_offset.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// Worst distance between the offset chain and the true offset of [source].
///
/// The chain is a chain, so its parameterization does not line up with the
/// source's; comparing by nearest point measures the geometry rather than the
/// parameterization.
double _worstDeviation(
  Cubic source,
  List<Cubic> offset,
  double distance, {
  int samples = 60,
}) {
  var worst = 0.0;

  for (var i = 0; i <= samples; i++) {
    final t = i / samples;
    final tangent = source.tangentAt(t);
    final target = source.pointAt(t) + leftNormal(tangent) * distance;

    var nearest = double.infinity;

    for (final segment in offset) {
      for (var j = 0; j <= samples; j++) {
        final d = segment.pointAt(j / samples).distanceTo(target);
        if (d < nearest) {
          nearest = d;
        }
      }
    }

    if (nearest > worst) {
      worst = nearest;
    }
  }

  return worst;
}

bool _isContinuous(List<Cubic> chain) {
  for (var i = 1; i < chain.length; i++) {
    if (chain[i - 1].p3.distanceTo(chain[i].p0) > 1e-6) {
      return false;
    }
  }

  return true;
}

void main() {
  const tolerance = 0.02;

  group('offsetCubic', () {
    test('offsets a straight segment as a single segment', () {
      final line = Cubic.line(Vector2(0, 0), Vector2(10, 0));
      final offset =
          const CubicOffsetter(distance: 1, tolerance: tolerance).offset(line);

      expect(offset, hasLength(1));
      expect(offset.single.p0.y, closeTo(1, 1e-9));
      expect(offset.single.p3.y, closeTo(1, 1e-9));
    });

    test('offsets a gentle curve within tolerance', () {
      final curve = Cubic(
        Vector2(0, 0),
        Vector2(0, 5),
        Vector2(10, 5),
        Vector2(10, 0),
      );

      for (final distance in [1.0, -1.0]) {
        final offset = CubicOffsetter(distance: distance, tolerance: tolerance)
            .offset(curve);

        expect(_isContinuous(offset), isTrue, reason: 'chain must not break');
        expect(
          _worstDeviation(curve, offset, distance),
          lessThanOrEqualTo(tolerance),
        );
      }
    });

    test('keeps a gentle curve to a handful of segments', () {
      // The whole point of offsetting curves rather than sampling them: this
      // used to take hundreds of line segments.
      final curve = Cubic(
        Vector2(0, 0),
        Vector2(0, 5),
        Vector2(10, 5),
        Vector2(10, 0),
      );

      expect(
          const CubicOffsetter(distance: 1, tolerance: tolerance)
              .offset(curve)
              .length,
          lessThan(8));
    });

    test('starts and ends exactly on the offset end points', () {
      final curve = Cubic(
        Vector2(0, 0),
        Vector2(2, 0),
        Vector2(4, 2),
        Vector2(4, 4),
      );
      const distance = 0.5;

      final offset = const CubicOffsetter(
        distance: distance,
        tolerance: tolerance,
      ).offset(curve);

      expect(
        offset.first.p0.distanceTo(
          curve.p0 + leftNormal(curve.tangentAt(0)) * distance,
        ),
        lessThan(1e-9),
      );
      expect(
        offset.last.p3.distanceTo(
          curve.p3 + leftNormal(curve.tangentAt(1)) * distance,
        ),
        lessThan(1e-9),
      );
    });

    test('does not run away inside a turn tighter than the offset', () {
      // Regression guard. Where `distance * curvature` reaches 1 the true offset
      // grows a cusp and doubles back, so no cubic converges on it. Subdividing
      // in the hope that it will produced thousands of segments per curve and
      // made the font larger than the polyline version it replaced.
      final tight = Cubic(
        Vector2(0, 0),
        Vector2(0.3, 0),
        Vector2(0.6, 0.3),
        Vector2(0.6, 0.6),
      );

      // 0.665 is half of the 1.33 stroke width these icon sets use, against a
      // corner radius well under that.
      final offset = const CubicOffsetter(distance: 0.665, tolerance: tolerance)
          .offset(tight);

      expect(
        offset.length,
        lessThan(8),
        reason: 'a degenerate offset must be recognised, not subdivided',
      );
      expect(offset, isNotEmpty, reason: 'the contour still has to close');
    });

    test('still offsets the outer side of a tight turn accurately', () {
      final tight = Cubic(
        Vector2(0, 0),
        Vector2(0.3, 0),
        Vector2(0.6, 0.3),
        Vector2(0.6, 0.6),
      );

      final offset =
          const CubicOffsetter(distance: -0.665, tolerance: tolerance)
              .offset(tight);

      expect(
        _worstDeviation(tight, offset, -0.665),
        lessThanOrEqualTo(tolerance),
      );
    });
  });
}
