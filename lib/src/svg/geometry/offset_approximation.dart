import 'package:vector_math/vector_math.dart';

import 'cubic.dart';
import 'tolerances.dart';

/// Parameters at which a candidate is checked against the true offset.
const _errorSamples = [0.25, 0.5, 0.75];

/// How close the cross product of the two *unit* end tangents may come to
/// zero and still be treated as exactly parallel.
///
/// This is not just a noise filter — it decides which branch below is used,
/// and the two branches differ in kind, not just in accuracy. In the
/// fallback, `alpha`/`beta` are functions of the source curve's own control
/// points alone, with no dependence on `distance`, so every emitted control
/// point is *exactly* affine in the stroke width — which is what lets one
/// low-width and one high-width master interpolate to every width in
/// between, the premise the variable-width axis is built on. In the solve
/// branch, `alpha`/`beta` are a quotient by `determinant`, which is
/// `distance`-independent but multiplies `target` — and `target` *does*
/// depend on `distance` — through a division that, near a singular
/// determinant, amplifies both float32 rounding and any residual
/// non-affine term in that dependence. Routing near-parallel geometry to the
/// fallback therefore does not just reduce noise; it moves that geometry
/// onto the branch that is structurally affine.
///
/// Thresholding the normalised cross product rather than the raw
/// `determinant` below (which carries an incidental factor of -9 from the
/// Bézier algebra) keeps this constant legible as "sine of the angle between
/// the tangents" on its own, and unaffected if that algebra changes or the
/// tangents stop being unit vectors.
///
/// Sized from two measurements, one per side, and both land on a plateau
/// rather than a knife edge — every fixture this package ships gives
/// identical piece counts at 1e-4, 3.66e-4, 2e-3 and 1e-2:
///
/// Lower bound — how big the float32 noise actually gets. [Cubic.tangentAt]
/// normalizes a *difference of control points*; for a straight source
/// segment, `p1 - p0` and `p3 - p2` are mathematically identical but computed
/// from independently-rounded sums, so they only agree to within the ULP of
/// the *coordinates*, not of the (possibly much shorter) tangent itself — a
/// corner far from the origin is the worst case. A multi-start search over
/// segment direction, length (0.5-50, the plausible-corner range `arc.dart`'s
/// own epsilon was sized from) and distance from the origin (up to 2000, that
/// same viewBox-scale envelope) converged on a worst-case cross product of
/// **3.66e-4** — matching the closed form (half the float32 ULP at that
/// coordinate scale, over a third of the segment length). This package's own
/// triangle fixture (`M12 2L22 20H2Z`) only hits 1.07e-7 on its one affected
/// edge, which is why a single example is not enough evidence.
///
/// Upper bound — how far this can reach before treating two tangents as
/// parallel is actually wrong. Rebuilding the 2x2 solve on shallow circular
/// arcs (genuine, non-zero tangent divergence, not noise) and comparing each
/// branch's deviation from the true offset as the arcs' sweep shrinks: the
/// solve is built on the same near-singular determinant as the noise
/// problem, so it degrades right where that problem lives — below cross
/// ~1e-3 it is no longer reliably better than the fallback, and above ~7e-3
/// it pulls decisively ahead (10-20x lower deviation). Between those, either
/// branch is within 1e-3 absolute deviation of the other — a rounding error
/// against [kCurveTolerance]'s 0.02 budget, further backstopped by the
/// recursive subdivision in `cubic_offset.dart`.
///
/// `2e-3` sits about 5.5x above the measured floor and in the lower half of
/// that ambiguous band — comfortably clear of both edges.
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
