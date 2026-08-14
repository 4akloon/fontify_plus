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
      final offset = const CubicOffsetter(
        distance: 1,
        tolerance: tolerance,
      ).offset(line);

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
        final offset = CubicOffsetter(
          distance: distance,
          tolerance: tolerance,
        ).offset(curve);

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
        const CubicOffsetter(
          distance: 1,
          tolerance: tolerance,
        ).offset(curve).length,
        lessThan(8),
      );
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
      final offset = const CubicOffsetter(
        distance: 0.665,
        tolerance: tolerance,
      ).offset(tight);

      expect(
        offset.length,
        lessThan(8),
        reason: 'a degenerate offset must be recognised, not subdivided',
      );
      expect(offset, isNotEmpty, reason: 'the contour still has to close');
    });

    test('does not chord a whole scallop because one end collapsed', () {
      // Same alien-02 wave. Only the last ~12% has distance*curvature ≥ 0.95;
      // the rest is a gentle outer wall. Treating any collapse as "the whole
      // cubic is degenerate" replaced the wave with one 3.7-unit chord —
      // triangular lobes at wght=3, even after looping handles were rejected.
      final scallop = Cubic(
        Vector2(12.0332, 21.9946),
        Vector2(13.3719, 21.8831),
        Vector2(14.4022, 20.2769),
        Vector2(15.4258, 20.2769),
      );

      const distance = 1.5;
      final offset = const CubicOffsetter(
        distance: distance,
        tolerance: tolerance,
      ).offset(scallop);

      expect(offset.length, greaterThan(1));

      final target =
          scallop.pointAt(0.35) +
          leftNormal(scallop.tangentAt(0.35)) * distance;
      var nearest = double.infinity;
      for (final piece in offset) {
        for (var j = 0; j <= 20; j++) {
          final d = piece.pointAt(j / 20).distanceTo(target);
          if (d < nearest) {
            nearest = d;
          }
        }
      }

      expect(
        nearest,
        lessThanOrEqualTo(tolerance),
        reason: 'the uncollapsed half must still track the true offset',
      );
    });

    test('does not emit looping handles on a collapsed scallop', () {
      // Bottom-right wave of Hugeicons alien-02. Offsetting this at radius
      // 1.5 produced a cubic whose handles sat on opposite sides of a 3.7
      // unit chord (x=23 and x=7) — the overlapping needles at wght=3.
      final scallop = Cubic(
        Vector2(12.0332, 21.9946),
        Vector2(13.3719, 21.8831),
        Vector2(14.4022, 20.2769),
        Vector2(15.4258, 20.2769),
      );

      for (final distance in [1.5, -1.5]) {
        final pieces = CubicOffsetter(
          distance: distance,
          tolerance: tolerance,
        ).offset(scallop);

        for (final piece in pieces) {
          final chord = piece.p0.distanceTo(piece.p3);

          expect(
            piece.p0.distanceTo(piece.p1),
            lessThanOrEqualTo(chord * 1.5 + 1e-6),
            reason: 'start handle must not loop past the chord',
          );
          expect(
            piece.p3.distanceTo(piece.p2),
            lessThanOrEqualTo(chord * 1.5 + 1e-6),
            reason: 'end handle must not loop past the chord',
          );
        }
      }
    });

    test('still offsets the outer side of a tight turn accurately', () {
      final tight = Cubic(
        Vector2(0, 0),
        Vector2(0.3, 0),
        Vector2(0.6, 0.3),
        Vector2(0.6, 0.6),
      );

      final offset = const CubicOffsetter(
        distance: -0.665,
        tolerance: tolerance,
      ).offset(tight);

      expect(
        _worstDeviation(tight, offset, -0.665),
        lessThanOrEqualTo(tolerance),
      );
    });
  });
}
