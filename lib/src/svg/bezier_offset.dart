import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// A cubic Bézier segment.
class Cubic {
  const Cubic(this.p0, this.p1, this.p2, this.p3);

  /// A straight line expressed as a cubic, with evenly spaced controls.
  factory Cubic.line(Vector2 start, Vector2 end) {
    final third = (end - start) / 3;

    return Cubic(start, start + third, end - third, end);
  }

  final Vector2 p0;
  final Vector2 p1;
  final Vector2 p2;
  final Vector2 p3;

  Vector2 pointAt(double t) {
    final u = 1 - t;

    return p0 * (u * u * u) +
        p1 * (3 * u * u * t) +
        p2 * (3 * u * t * t) +
        p3 * (t * t * t);
  }

  /// Unit tangent at [t].
  ///
  /// The derivative vanishes when control points coincide — a common way to
  /// write a curve with a flat start — so fall back to the next non-degenerate
  /// difference rather than returning a zero vector.
  Vector2 tangentAt(double t) {
    final u = 1 - t;
    final derivative = (p1 - p0) * (3 * u * u) +
        (p2 - p1) * (6 * u * t) +
        (p3 - p2) * (3 * t * t);

    if (derivative.length2 > _epsilon) {
      return derivative.normalized();
    }

    for (final fallback in [p3 - p0, p2 - p0, p3 - p1]) {
      if (fallback.length2 > _epsilon) {
        return fallback.normalized();
      }
    }

    return Vector2(1, 0);
  }

  /// Splits at [t] into the two halves, by de Casteljau.
  (Cubic, Cubic) splitAt(double t) {
    final a = p0 + (p1 - p0) * t;
    final b = p1 + (p2 - p1) * t;
    final c = p2 + (p3 - p2) * t;
    final d = a + (b - a) * t;
    final e = b + (c - b) * t;
    final f = d + (e - d) * t;

    return (Cubic(p0, a, d, f), Cubic(f, e, c, p3));
  }
}

/// Left-hand normal of a unit direction.
Vector2 leftNormal(Vector2 direction) => Vector2(-direction.y, direction.x);

/// Approximates the offset of [curve] at [distance] to its left, as a chain of
/// cubics accurate to [tolerance].
///
/// The offset of a cubic is not itself a cubic — it is generally a curve of
/// much higher degree — so it has to be approximated. Doing that directly
/// beats flattening the source to a polyline and refitting: the endpoints and
/// end tangents of the offset are known exactly, so only the control point
/// distances need solving, and the result tracks the true offset with far fewer
/// segments than fitting to sampled points ever recovers.
List<Cubic> offsetCubic(Cubic curve, double distance, double tolerance) {
  final result = <Cubic>[];

  _offset(curve, distance, tolerance, result, 0);

  return result;
}

/// Approximates a circular arc as a chain of cubics.
///
/// Round joins and caps are exact circular arcs. Sampling them into a polyline
/// is what made caps cost a dozen points each; a quarter turn is within a
/// fraction of a unit of a single cubic.
List<Cubic> arcToCubics(
  Vector2 centre,
  double radius,
  double startAngle,
  double sweep,
) {
  if (radius <= _epsilon || sweep.abs() <= _epsilon) {
    return const [];
  }

  // Error grows sharply past a quarter turn, so never span more than one.
  final count = (sweep.abs() / (math.pi / 2)).ceil();
  final step = sweep / count;

  // Control point distance that makes a cubic match a circular arc: the
  // standard 4/3 tan(theta/4).
  final handle = 4 / 3 * math.tan(step / 4) * radius;

  final result = <Cubic>[];
  var angle = startAngle;

  for (var i = 0; i < count; i++) {
    final next = angle + step;

    final from = centre + Vector2(math.cos(angle), math.sin(angle)) * radius;
    final to = centre + Vector2(math.cos(next), math.sin(next)) * radius;

    // Tangents run perpendicular to the radius, in the direction of travel.
    final fromTangent = Vector2(-math.sin(angle), math.cos(angle));
    final toTangent = Vector2(-math.sin(next), math.cos(next));

    result.add(
      Cubic(from, from + fromTangent * handle, to - toTangent * handle, to),
    );

    angle = next;
  }

  return result;
}

const _epsilon = 1e-12;

/// Recursion cap, as a backstop behind the degeneracy check below.
const _maxDepth = 8;

/// How close `distance * curvature` may come to 1 before the offset is treated
/// as degenerate.
///
/// The offset curve's speed is proportional to `1 - distance * curvature`, so at
/// 1 it stalls and beyond it reverses: the true offset grows a cusp and doubles
/// back on itself. No cubic tracks that, and subdividing only produces more
/// segments that each fail the same way.
const _degenerateCurvature = 0.95;

/// Parameters at which the candidate is checked against the true offset.
const _errorSamples = [0.25, 0.5, 0.75];

void _offset(
  Cubic curve,
  double distance,
  double tolerance,
  List<Cubic> out,
  int depth,
) {
  final candidate = _approximate(curve, distance);

  if (candidate != null &&
      (depth >= _maxDepth ||
          _maxDeviation(curve, candidate, distance) <= tolerance)) {
    out.add(candidate);
    return;
  }

  // Inside a turn tighter than the offset itself there is no curve to converge
  // on. This is the normal case at a rounded corner narrower than the stroke,
  // not an error: the inner wall folds over itself and the nonzero rule absorbs
  // the overlap, so take the best approximation and stop.
  if (_isDegenerate(curve, distance)) {
    out.add(candidate ?? _chord(curve, distance));
    return;
  }

  if (depth >= _maxDepth) {
    // No usable approximation and no budget left: fall back to the chord so the
    // contour stays closed rather than dropping a piece of the outline.
    out.add(_chord(curve, distance));
    return;
  }

  final (left, right) = curve.splitAt(0.5);

  _offset(left, distance, tolerance, out, depth + 1);
  _offset(right, distance, tolerance, out, depth + 1);
}

/// Builds one offset cubic for [curve], or null when the geometry is degenerate.
///
/// End points and end tangents of the offset are exact. The two control point
/// distances are then chosen so the curve also passes through the true offset
/// at its midpoint, which is the constraint that keeps it from bowing.
Cubic? _approximate(Cubic curve, double distance) {
  final startTangent = curve.tangentAt(0);
  final endTangent = curve.tangentAt(1);

  final start = curve.p0 + leftNormal(startTangent) * distance;
  final end = curve.p3 + leftNormal(endTangent) * distance;

  final midpoint = _offsetPointAt(curve, 0.5, distance);

  // C(0.5) = (4*start + 4*end + 3*a*startTangent - 3*b*endTangent) / 8
  final target = midpoint * 8.0 - start * 4.0 - end * 4.0;

  final determinant =
      -9 * (startTangent.x * endTangent.y - endTangent.x * startTangent.y);

  double alpha;
  double beta;

  if (determinant.abs() > _epsilon) {
    alpha = (target.x * -3 * endTangent.y - -3 * endTangent.x * target.y) /
        determinant;
    beta = (3 * startTangent.x * target.y - target.x * 3 * startTangent.y) /
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

/// The straight line between the offset end points.
Cubic _chord(Cubic curve, double distance) => Cubic.line(
      curve.p0 + leftNormal(curve.tangentAt(0)) * distance,
      curve.p3 + leftNormal(curve.tangentAt(1)) * distance,
    );

/// Whether offsetting [curve] by [distance] collapses somewhere along it.
bool _isDegenerate(Cubic curve, double distance) {
  for (var i = 0; i <= 8; i++) {
    if (distance * _curvatureAt(curve, i / 8) >= _degenerateCurvature) {
      return true;
    }
  }

  return false;
}

/// Signed curvature at [t]; positive where the curve turns toward its left
/// normal, which is the direction the offset moves.
double _curvatureAt(Cubic curve, double t) {
  final u = 1 - t;

  final d1 = (curve.p1 - curve.p0) * (3 * u * u) +
      (curve.p2 - curve.p1) * (6 * u * t) +
      (curve.p3 - curve.p2) * (3 * t * t);
  final d2 = (curve.p2 - curve.p1 * 2.0 + curve.p0) * (6 * u) +
      (curve.p3 - curve.p2 * 2.0 + curve.p1) * (6 * t);

  final speed = d1.length;

  if (speed <= _epsilon) {
    return 0;
  }

  return (d1.x * d2.y - d1.y * d2.x) / (speed * speed * speed);
}

Vector2 _offsetPointAt(Cubic curve, double t, double distance) =>
    curve.pointAt(t) + leftNormal(curve.tangentAt(t)) * distance;

/// Worst distance between [candidate] and the true offset of [curve].
double _maxDeviation(Cubic curve, Cubic candidate, double distance) {
  var worst = 0.0;

  for (final t in _errorSamples) {
    final deviation =
        candidate.pointAt(t).distanceTo(_offsetPointAt(curve, t, distance));

    if (deviation > worst) {
      worst = deviation;
    }
  }

  return worst;
}
