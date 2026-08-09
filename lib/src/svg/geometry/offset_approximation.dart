import 'package:vector_math/vector_math.dart';

import 'cubic.dart';
import 'tolerances.dart';

/// Parameters at which a candidate is checked against the true offset.
const _errorSamples = [0.25, 0.5, 0.75];

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

  final determinant =
      -9 * (startTangent.x * endTangent.y - endTangent.x * startTangent.y);

  double alpha;
  double beta;

  if (determinant.abs() > kZeroLength) {
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
