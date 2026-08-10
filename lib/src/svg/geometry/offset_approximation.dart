import 'package:vector_math/vector_math.dart';

import 'cubic.dart';
import 'tolerances.dart';

/// Parameters at which a candidate is checked against the true offset.
const _errorSamples = [0.25, 0.5, 0.75];

/// How close the cross product of the two *unit* end tangents may come to
/// zero and still be treated as exactly parallel.
///
/// Thresholding the normalised cross product rather than the raw
/// `determinant` below (which carries an incidental factor of -9 from the
/// Bézier algebra) keeps this constant meaning "sine of the angle between
/// the tangents" on its own — legible without the -9 in your head, and
/// unaffected if that algebra ever changes or the tangents stop being unit
/// vectors.
///
/// [Cubic.tangentAt] normalizes a *difference of control points* — for a
/// straight source segment, `p1 - p0` and `p3 - p2` are mathematically the
/// same vector, but [Vector2] is float32-backed, so the two differences are
/// computed from independently-rounded sums and only agree to within a few
/// ULPs of the *coordinates*, not of the tiny vector itself. A corner far
/// from the origin makes that ULP large while the tangent it's measured
/// against can still be short, which is the worst case for the resulting
/// angular noise.
///
/// Sized from two independent measurements, one per side:
///
/// Lower bound — how big the noise actually gets. Reproducing
/// `SubPathBuilder`'s own construction (`Cubic.line` from an SVG "L"
/// segment, then `tangentAt(0)`/`tangentAt(1)`, exactly as this function
/// calls them) with the segment's direction, length (0.5-50, the same
/// plausible-corner-geometry range `arc.dart`'s epsilon was sized from) and
/// the corner's distance from the origin (up to 2000, that same viewBox-scale
/// envelope) all varied, a multi-start bounded search over that space — not
/// a single example — converged on a worst-case cross product of
/// **2.8e-4** (determinant 2.5e-3). This package's own triangle fixture
/// (`M12 2L22 20H2Z`) hits a smaller 1.07e-7 on its one affected edge, which
/// is why one adversarial example is not enough evidence: the noise is
/// direction- and scale-dependent and this triangle happened to land in a
/// mild spot.
///
/// Upper bound — how far this can reach before treating two tangents as
/// parallel is actually wrong. This isn't a fixed geometric tolerance:
/// rebuilding [approximateOffset]'s own 2x2 solve on a family of shallow
/// circular arcs (genuine, non-zero tangent divergence, not noise) shows the
/// solve is itself built on the same near-singular determinant, so it
/// degrades exactly where the noise problem lives. Comparing the solve
/// against the parallel fallback's deviation from the true offset as the
/// arcs' sweep shrinks: below cross ~1e-3 the "solve" is already
/// unreliable — sometimes a little better, sometimes producing no valid
/// candidate at all (alpha/beta run negative or non-finite) — while the
/// fallback stays well-behaved throughout. Above cross ~7e-3 the solve pulls
/// decisively and consistently ahead (10-20x lower deviation). In between,
/// which one wins swings unpredictably by less than 1e-3 absolute deviation
/// either way — a rounding error next to [kCurveTolerance]'s 0.02 budget,
/// which the recursive subdivision in `cubic_offset.dart` backstops anyway
/// if a candidate does come out worse than expected.
///
/// `2e-3` sits about 7x above the measured noise floor and inside the lower
/// half of that ambiguous middle band — comfortably clear of both edges.
const _kParallelTangentEpsilon = 2e-3;

/// The point on the true offset of [curve] at [t].
Vector2 offsetPointAt(Cubic curve, double t, double distance) =>
    curve.pointAt(t) + leftNormal(curve.tangentAt(t)) * distance;

/// The straight line between the offset end points.
Cubic offsetChord(Cubic curve, double distance) => Cubic.line(
  offsetPointAt(curve, 0, distance),
  offsetPointAt(curve, 1, distance),
);

/// Worst distance between [candidate] and the true offset of [curve].
double maxOffsetDeviation(Cubic curve, Cubic candidate, double distance) {
  var worst = 0.0;

  for (final t in _errorSamples) {
    final deviation = candidate
        .pointAt(t)
        .distanceTo(offsetPointAt(curve, t, distance));

    if (deviation > worst) {
      worst = deviation;
    }
  }

  return worst;
}

/// Builds one offset cubic for [curve], or null when the geometry is
/// degenerate.
///
/// End points and end tangents of the offset are exact. The two control point
/// distances are then chosen so the curve also passes through the true offset
/// at its midpoint, which is the constraint that keeps it from bowing.
Cubic? approximateOffset(Cubic curve, double distance) {
  final startTangent = curve.tangentAt(0);
  final endTangent = curve.tangentAt(1);

  final start = curve.p0 + leftNormal(startTangent) * distance;
  final end = curve.p3 + leftNormal(endTangent) * distance;

  final midpoint = offsetPointAt(curve, 0.5, distance);

  // C(0.5) = (4*start + 4*end + 3*a*startTangent - 3*b*endTangent) / 8
  final target = midpoint * 8.0 - start * 4.0 - end * 4.0;

  final cross = startTangent.x * endTangent.y - endTangent.x * startTangent.y;
  final determinant = -9 * cross;

  double alpha;
  double beta;

  if (cross.abs() > _kParallelTangentEpsilon) {
    alpha =
        (target.x * -3 * endTangent.y - -3 * endTangent.x * target.y) /
        determinant;
    beta =
        (3 * startTangent.x * target.y - target.x * 3 * startTangent.y) /
        determinant;
  } else {
    // Parallel end tangents: the offset is essentially a translation, so keep
    // the source curve's own control spacing.
    alpha = curve.p0.distanceTo(curve.p1);
    beta = curve.p2.distanceTo(curve.p3);
  }

  // A non-positive distance folds the control point behind its end point,
  // which loops the curve. Let the caller subdivide instead.
  if (!alpha.isFinite || !beta.isFinite || alpha <= 0 || beta <= 0) {
    return null;
  }

  return Cubic(
    start,
    start + startTangent * alpha,
    end - endTangent * beta,
    end,
  );
}
